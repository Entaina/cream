/**
 * Gmail contextual add-on: link the open thread to a CReaM deal or create a new deal.
 */
var CREAM_PIPELINE_KEY = "cream.pipeline_id";

function onGmailMessageOpen(e) {
  if (!hasCreamAccess_()) {
    return [ buildConnectCard_() ];
  }

  try {
    var threadData = readOpenThread_(e);
    var status = threadStatus_(threadData);
    applyLinkedWorkspace_(status);
    var context = creamContext_();
    resolveDestination_(context);
    return [ buildThreadCard_(threadData, status, context) ];
  } catch (err) {
    if (String(err.message) === "not_connected") {
      return [ buildConnectCard_() ];
    }
    return [ buildErrorCard_(err.message) ];
  }
}

function readOpenThread_(e) {
  GmailApp.setCurrentMessageAccessToken(e.gmail.accessToken);
  var message = GmailApp.getMessageById(e.gmail.messageId);
  var thread = message.getThread();
  var messages = thread.getMessages();
  var serialized = [];
  var rfc822Ids = [];
  var participants = [];

  messages.forEach(function(msg) {
    var from = msg.getFrom() || "";
    var to = msg.getTo() || "";
    var messageId = msg.getHeader("Message-ID") || "";
    participants.push(from, to);
    if (messageId) {
      rfc822Ids.push(messageId);
    }
    serialized.push({
      gmail_message_id: msg.getId(),
      rfc822_message_id: messageId,
      from: from,
      to: to,
      subject: msg.getSubject() || "",
      body: msg.getPlainBody() || "",
      sent_at: msg.getDate().toISOString()
    });
  });

  return {
    gmail_thread_id: (e.gmail && e.gmail.threadId) || thread.getId(),
    gmail_message_id: e.gmail.messageId,
    subject: message.getSubject() || "",
    messages: serialized,
    rfc822_message_ids: rfc822Ids,
    participant_emails: participants
  };
}

function userProperty_(key) {
  return PropertiesService.getUserProperties().getProperty(key);
}

function setUserProperty_(key, value) {
  var properties = PropertiesService.getUserProperties();
  if (value) {
    properties.setProperty(key, String(value));
  } else {
    properties.deleteProperty(key);
  }
}

function findById_(records, id) {
  id = String(id || "");
  return (records || []).filter(function(record) {
    return String(record.id) === id;
  })[0] || null;
}

function resolveDestination_(context) {
  var workspaces = context.workspaces || [];
  var workspace = findById_(workspaces, getSelectedWorkspaceId_());
  if (!workspace) {
    workspace = workspaces.filter(function(item) {
      return String(item.name).toLowerCase() === "example";
    })[0] || findById_(workspaces, context.selected_workspace_id) || workspaces[0];
  }
  if (!workspace) {
    throw new Error("Your CReaM account has no available workspace.");
  }
  setSelectedWorkspaceId_(workspace.id);

  var pipelines = workspace.pipelines || [];
  var pipeline = findById_(pipelines, userProperty_(CREAM_PIPELINE_KEY));
  if (!pipeline) {
    pipeline = findById_(pipelines, workspace.default_pipeline_id) ||
      pipelines.filter(function(item) { return item.default; })[0] ||
      pipelines[0];
  }
  if (!pipeline) {
    throw new Error("The selected workspace has no pipeline.");
  }
  setUserProperty_(CREAM_PIPELINE_KEY, pipeline.id);

  var stages = pipeline.stages || [];
  var stage = stages[0];
  if (!stage) {
    throw new Error("The selected pipeline has no stage.");
  }

  return {
    workspaces: workspaces,
    workspace: workspace,
    pipelines: pipelines,
    pipeline: pipeline,
    stage: stage
  };
}

function buildDestinationSection_(context) {
  var destination = resolveDestination_(context);
  var section = CardService.newCardSection().setHeader("Destination");
  var workspaceInput = CardService.newSelectionInput()
    .setType(CardService.SelectionInputType.DROPDOWN)
    .setFieldName("workspace_id")
    .setTitle("Workspace")
    .setOnChangeAction(CardService.newAction().setFunctionName("changeWorkspace"));
  destination.workspaces.forEach(function(workspace) {
    workspaceInput.addItem(
      workspace.name,
      String(workspace.id),
      workspace.id === destination.workspace.id
    );
  });

  var pipelineInput = CardService.newSelectionInput()
    .setType(CardService.SelectionInputType.DROPDOWN)
    .setFieldName("pipeline_id")
    .setTitle("Pipeline")
    .setOnChangeAction(CardService.newAction().setFunctionName("changePipeline"));
  destination.pipelines.forEach(function(pipeline) {
    pipelineInput.addItem(
      pipeline.name,
      String(pipeline.id),
      pipeline.id === destination.pipeline.id
    );
  });

  section.addWidget(workspaceInput);
  section.addWidget(pipelineInput);
  section.addWidget(
    CardService.newDecoratedText()
      .setTopLabel("Initial stage")
      .setText(destination.stage.name)
  );
  return section;
}

function formValue_(e, fieldName) {
  if (e.formInput && e.formInput[fieldName] !== undefined) {
    return e.formInput[fieldName];
  }
  var formInputs = e.commonEventObject && e.commonEventObject.formInputs;
  var values = formInputs && formInputs[fieldName] &&
    formInputs[fieldName].stringInputs && formInputs[fieldName].stringInputs.value;
  return values && values.length ? values[0] : null;
}

function refreshThreadCard_(e) {
  return refreshThreadCardAfterLink_(e, null);
}

function changeWorkspace(e) {
  setSelectedWorkspaceId_(formValue_(e, "workspace_id"));
  setUserProperty_(CREAM_PIPELINE_KEY, null);
  return refreshLinkActionsCard_(e);
}

function changePipeline(e) {
  setUserProperty_(CREAM_PIPELINE_KEY, formValue_(e, "pipeline_id"));
  return refreshLinkActionsCard_(e);
}

function threadStatus_(threadData) {
  return creamThreadStatus_({
    gmail_thread_id: threadData.gmail_thread_id,
    rfc822_message_ids: threadData.rfc822_message_ids,
    participant_emails: threadData.participant_emails
  });
}

function applyLinkedWorkspace_(status) {
  if (!status.linked || !status.linked.length) {
    return;
  }
  var workspaceId = status.linked[0].workspace_id;
  if (workspaceId) {
    setSelectedWorkspaceId_(workspaceId);
  }
}

function formatDealValue_(deal) {
  if (deal.value === undefined || deal.value === null) {
    return null;
  }
  var amount = Number(deal.value).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  });
  return deal.currency ? amount + " " + deal.currency : amount;
}

function formatIsoDate_(value) {
  if (!value) {
    return null;
  }
  var date = new Date(value);
  if (isNaN(date.getTime())) {
    return value;
  }
  return Utilities.formatDate(date, Session.getScriptTimeZone(), "dd MMM yyyy");
}

function addDealField_(section, label, value) {
  if (value === undefined || value === null || value === "") {
    return;
  }
  section.addWidget(
    CardService.newDecoratedText()
      .setTopLabel(label)
      .setText(String(value))
      .setWrapText(true)
  );
}

function buildLinkedDealSection_(deal, multipleDeals) {
  var header = multipleDeals ? deal.name : "Linked deal";
  var section = CardService.newCardSection().setHeader(header);
  if (multipleDeals) {
    addDealField_(section, "Deal", deal.name);
  }
  var stagePipeline = [deal.stage, deal.pipeline].filter(Boolean).join(" · ");
  addDealField_(section, "Stage", stagePipeline);
  addDealField_(section, "Company", deal.company_name);
  addDealField_(section, "Value", formatDealValue_(deal));
  addDealField_(section, "Owner", deal.owner_name);
  if (deal.contacts && deal.contacts.length) {
    addDealField_(section, "Contacts", deal.contacts.join(", "));
  }
  addDealField_(section, "Close date", formatIsoDate_(deal.expected_close_date));
  if (deal.next_task) {
    var taskText = deal.next_task.title;
    if (deal.next_task.due_on) {
      taskText += " (due " + formatIsoDate_(deal.next_task.due_on) + ")";
    }
    addDealField_(section, "Next task", taskText);
  }
  if (deal.products && deal.products.length) {
    addDealField_(section, "Products", deal.products.join("\n"));
  }
  if (deal.url) {
    section.addWidget(
      CardService.newTextButton()
        .setText("Open in CReaM")
        .setOpenLink(CardService.newOpenLink().setUrl(deal.url))
    );
  }
  return section;
}

function buildLinkActionsCard_(threadData, status, context) {
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle("Link deal"));
  if (threadData.gmail_message_id) {
    card.setName(threadData.gmail_message_id);
  }

  card.addSection(buildDestinationSection_(context));

  if (status.suggestions && status.suggestions.length) {
    var suggestions = CardService.newCardSection().setHeader("Suggested deals");
    status.suggestions.forEach(function(deal) {
      suggestions.addWidget(
        CardService.newTextButton()
          .setText("Link to " + deal.name)
          .setOnClickAction(
            CardService.newAction()
              .setFunctionName("linkToDeal")
              .setParameters({ deal_id: String(deal.id), gmail_thread_id: threadData.gmail_thread_id })
          )
      );
    });
    card.addSection(suggestions);
  }

  var actions = CardService.newCardSection().setHeader("Search");
  actions.addWidget(
    CardService.newTextInput()
      .setFieldName("deal_query")
      .setTitle("Search deals")
      .setHint("Type a deal or company name")
  );
  actions.addWidget(
    CardService.newTextButton()
      .setText("Search")
      .setOnClickAction(
        CardService.newAction()
          .setFunctionName("searchDeals")
          .setParameters({ gmail_thread_id: threadData.gmail_thread_id })
      )
  );

  var createSection = CardService.newCardSection().setHeader("Create deal");
  createSection.addWidget(
    CardService.newTextInput()
      .setFieldName("deal_name")
      .setTitle("Deal name")
      .setValue(threadData.subject || "Deal from email")
  );
  createSection.addWidget(
    CardService.newTextButton()
      .setText("Create deal from thread")
      .setOnClickAction(
        CardService.newAction()
          .setFunctionName("createDealFromThread")
          .setParameters({ gmail_thread_id: threadData.gmail_thread_id })
      )
  );

  card.addSection(actions);
  card.addSection(createSection);
  return card.build();
}

function buildThreadCard_(threadData, status, context) {
  if (!status.linked || !status.linked.length) {
    return buildLinkActionsCard_(threadData, status, context);
  }

  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle("CReaM"));
  if (threadData.gmail_message_id) {
    card.setName(threadData.gmail_message_id);
  }

  var multipleDeals = status.linked.length > 1;
  status.linked.forEach(function(deal) {
    card.addSection(buildLinkedDealSection_(deal, multipleDeals));
  });

  var actions = CardService.newCardSection();
  actions.addWidget(
    CardService.newTextButton()
      .setText("Link another deal")
      .setOnClickAction(CardService.newAction().setFunctionName("showLinkActions"))
  );
  card.addSection(actions);
  return card.build();
}

function refreshLinkActionsCard_(e) {
  var threadData = readOpenThread_(e);
  var context = creamContext_();
  var status = threadStatus_(threadData);
  return CardService.newActionResponseBuilder()
    .setNavigation(
      CardService.newNavigation().updateCard(buildLinkActionsCard_(threadData, status, context))
    )
    .build();
}

function showLinkActions(e) {
  try {
    var threadData = readOpenThread_(e);
    var context = creamContext_();
    var status = threadStatus_(threadData);
    return CardService.newActionResponseBuilder()
      .setNavigation(
        CardService.newNavigation().pushCard(buildLinkActionsCard_(threadData, status, context))
      )
      .build();
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}

function refreshThreadCardAfterLink_(e, message) {
  var threadData = readOpenThread_(e);
  var status = threadStatus_(threadData);
  applyLinkedWorkspace_(status);
  var context = creamContext_();
  var builder = CardService.newActionResponseBuilder()
    .setNavigation(
      CardService.newNavigation().updateCard(buildThreadCard_(threadData, status, context))
    );
  if (message) {
    builder.setNotification(CardService.newNotification().setText(message));
  }
  return builder.build();
}

function buildErrorCard_(message) {
  return CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle("CReaM"))
    .addSection(
      CardService.newCardSection().addWidget(
        CardService.newTextParagraph().setText(String(message))
      )
    )
    .build();
}

function linkToDeal(e) {
  try {
    var threadData = readOpenThread_(e);
    var dealId = e.parameters.deal_id;
    var result = creamThreadLink_({
      deal_id: Number(dealId),
      thread: {
        gmail_thread_id: threadData.gmail_thread_id,
        messages: threadData.messages
      }
    });
    return refreshThreadCardAfterLink_(
      e,
      "Linked " + result.imported_count + " message(s) to " + result.deal.name
    );
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}

function createDealFromThread(e) {
  try {
    var threadData = readOpenThread_(e);
    var dealName = formValue_(e, "deal_name") || threadData.subject || "Deal from email";
    var destination = resolveDestination_(creamContext_());
    var result = creamThreadLink_({
      new_deal: { name: dealName, pipeline_stage_id: Number(destination.stage.id) },
      thread: {
        gmail_thread_id: threadData.gmail_thread_id,
        messages: threadData.messages
      }
    });
    return refreshThreadCardAfterLink_(
      e,
      "Created deal \"" + result.deal.name + "\" with " + result.imported_count + " message(s)"
    );
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}

function searchDeals(e) {
  try {
    var query = formValue_(e, "deal_query") || "";
    var deals = creamSearchDeals_(query);
    var threadData = readOpenThread_(e);
    var card = CardService.newCardBuilder()
      .setHeader(CardService.newCardHeader().setTitle("Search results"));
    var section = CardService.newCardSection();
    if (!deals.length) {
      section.addWidget(CardService.newTextParagraph().setText("No deals found."));
    } else {
      deals.forEach(function(deal) {
        section.addWidget(
          CardService.newTextButton()
            .setText(deal.name)
            .setOnClickAction(
              CardService.newAction()
                .setFunctionName("linkToDeal")
                .setParameters({ deal_id: String(deal.id), gmail_thread_id: threadData.gmail_thread_id })
            )
        );
      });
    }
    card.addSection(section);
    return CardService.newActionResponseBuilder()
      .setNavigation(CardService.newNavigation().pushCard(card.build()))
      .build();
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}
