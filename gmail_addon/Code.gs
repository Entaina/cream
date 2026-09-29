/**
 * Gmail contextual add-on: link the open thread to a CReaM deal or create a new deal.
 */
var CREAM_PIPELINE_KEY = "cream.pipeline_id";

function onGmailMessageOpen(e) {
  var authCard = gmailAuthorizationCard_();
  if (authCard) return [ authCard ];
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
  var threadId = (e.gmail && e.gmail.threadId) || "";
  if (!gmailReadonlyGranted_()) {
    var currentOnly = serializeCurrentMessage_(message);
    var subject = safeMessageValue_(function() { return message.getSubject(); });
    return threadPayload_(threadId || message.getId(), e.gmail.messageId, subject, currentOnly ? [currentOnly] : []);
  }
  var thread = message.getThread();
  if (!threadId) threadId = thread.getId();
  var apiMessages = gmailApiMessagesForThread_(threadId, e.gmail.messageId, message);
  var appMessages = gmailAppMessages_(thread, message);
  var messages = apiMessages.length >= appMessages.length ? apiMessages : appMessages;
  if (!messages.length) {
    var current = serializeGmailMessage_(message);
    if (current) messages = [current];
  }
  var participants = messageParticipants_(message);
  var related = relatedMessagesBySubject_(message.getSubject(), participants, messages);
  var linked = relatedByHeadersAndCalendar_(e.gmail.messageId, messages.concat(related));
  if (related.length || linked.length) {
    messages = messages.concat(related).concat(linked);
  }
  return threadPayload_(threadId, e.gmail.messageId, message.getSubject() || "", messages);
}

function relatedMessagesBySubject_(subject, participants, already) {
  var normalized = normalizedSubject_(subject);
  var participantList = Object.keys(participants || {});
  if (normalized.length < 3 || !participantList.length) return [];
  var listed = gmailGet_("messages?maxResults=15&q=" + encodeURIComponent('subject:"' + normalized.replace(/"/g, "") + '"'));
  var seen = {};
  var seenThreads = {};
  (already || []).forEach(function(item) {
    seen[item.gmail_message_id] = true;
  });
  var extra = [];
  ((listed && listed.messages) || []).forEach(function(item) {
    if (!item.id || seen[item.id]) return;
    var full = gmailGet_("messages/" + encodeURIComponent(item.id) + "?format=full");
    if (!full || !full.threadId || seenThreads[full.threadId]) return;
    seenThreads[full.threadId] = true;
    var thread = gmailGet_("threads/" + encodeURIComponent(full.threadId) + "?format=full");
    var threadMessages = (thread && thread.messages) || [full];
    if (!sharesParticipant_(threadMessages, participants)) return;
    var mapped = mapGmailMessages_(thread);
    if (!mapped.length) mapped = mapGmailMessages_([full]);
    mapped.forEach(function(message) {
      if (seen[message.gmail_message_id]) return;
      if (normalizedSubject_(message.subject) !== normalized) return;
      seen[message.gmail_message_id] = true;
      extra.push(message);
    });
  });
  return extra;
}

function relatedByHeadersAndCalendar_(messageId, already) {
  var full = gmailGet_("messages/" + encodeURIComponent(messageId) + "?format=full");
  if (!full || !full.payload) return [];
  var headers = headerMap_(full.payload.headers);
  var references = referencedMessageIds_(headers.references, headers["in-reply-to"]);
  var uid = calendarUid_(full.payload, full.id);
  var token = calendarSearchToken_(uid);
  var seen = {};
  (already || []).forEach(function(item) { seen[item.gmail_message_id] = true; });
  var extra = [];
  var participants = messageParticipantsFromPayload_(full.payload);
  references.forEach(function(reference) {
    addThreadByQuery_('rfc822msgid:' + reference, seen, extra);
  });
  if (token) addThreadByQuery_(token, seen, extra);
  var subject = normalizedSubject_(headers.subject);
  if (subject.length >= 3) addThreadByQuery_('"' + subject.replace(/"/g, "") + '"', seen, extra, participants);
  return extra;
}

function addThreadByQuery_(query, seen, extra, participants) {
  var listed = gmailGet_("messages?maxResults=10&q=" + encodeURIComponent(query));
  var seenThreads = {};
  ((listed && listed.messages) || []).forEach(function(item) {
    if (!item.id || seen[item.id]) return;
    var full = gmailGet_("messages/" + encodeURIComponent(item.id) + "?format=full");
    if (!full || !full.threadId || seenThreads[full.threadId]) return;
    seenThreads[full.threadId] = true;
    var thread = gmailGet_("threads/" + encodeURIComponent(full.threadId) + "?format=full");
    var threadMessages = (thread && thread.messages) || [full];
    if (participants && !sharesParticipant_(threadMessages, participants)) return;
    var mapped = mapGmailMessages_(thread);
    if (!mapped.length) mapped = mapGmailMessages_([full]);
    mapped.forEach(function(message) {
      if (seen[message.gmail_message_id]) return;
      seen[message.gmail_message_id] = true;
      extra.push(message);
    });
  });
}

function messageParticipantsFromPayload_(payload) {
  var headers = headerMap_(payload && payload.headers);
  return emailsIn_([headers.from, headers.to, headers.cc].join(","));
}

function calendarSearchToken_(uid) {
  var marker = "040000008200E00074C5B7101A82E00800000000";
  var rest = uid.indexOf(marker) === 0 ? uid.slice(marker.length) : uid;
  return rest.slice(0, 16);
}

function referencedMessageIds_(references, inReplyTo) {
  var ids = {};
  (String(references || "") + " " + String(inReplyTo || "")).split(/\s+/).forEach(function(token) {
    var id = token.replace(/^<|>$/g, "").trim();
    if (id.indexOf("@") > 0) ids[id] = true;
  });
  return Object.keys(ids);
}

function unfoldIcs_(text) {
  return String(text || "").replace(/\r?\n[ \t]/g, "");
}

function calendarUid_(payload, messageId) {
  var collected = {plain: "", html: "", calendar: ""};
  collectPayload_(payload, collected, messageId);
  var match = unfoldIcs_(collected.calendar).match(/^UID:(.*)$/im);
  return match ? match[1].trim() : "";
}

function messageParticipants_(gmailMessage) {
  return emailsIn_([
    safeMessageValue_(function() { return gmailMessage.getFrom(); }),
    safeMessageValue_(function() { return gmailMessage.getTo(); }),
    safeMessageValue_(function() { return gmailMessage.getCc(); })
  ].join(","));
}

function sharesParticipant_(apiMessages, participants) {
  var shared = false;
  (apiMessages || []).forEach(function(message) {
    if (shared) return;
    var headers = headerMap_(message.payload && message.payload.headers);
    var emails = emailsIn_([headers.from, headers.to, headers.cc].join(","));
    Object.keys(emails).forEach(function(email) {
      if (participants[email]) shared = true;
    });
  });
  return shared;
}

function emailsIn_(raw) {
  var found = {};
  String(raw || "").split(/[,;]/).forEach(function(part) {
    var email = emailAddress_(part);
    if (email) found[email] = true;
  });
  return found;
}

function emailAddress_(raw) {
  var match = String(raw || "").match(/<([^>]+)>/);
  var email = (match ? match[1] : raw).trim().toLowerCase();
  return email.indexOf("@") > 0 ? email : "";
}

function normalizedSubject_(subject) {
  var text = String(subject || "").trim();
  var prefix = /^(re|rv|fwd|fw|wg|cancelado|canceled|cancelled|invitacion|invitación|invitation|updated|actualizado|actualizacion|actualización|accepted|aceptado|declined|rechazado|tentative|provisional)\s*:\s*/i;
  var previous = "";
  while (text && text !== previous) {
    previous = text;
    text = text.replace(prefix, "").trim();
  }
  return text;
}

function gmailAppMessages_(thread, current) {
  var messages = [];
  try {
    messages = thread.getMessages() || [];
  } catch (err) {
    messages = [];
  }
  if (!messages.length) messages = [current];
  var serialized = [];
  messages.forEach(function(msg) {
    var item = serializeGmailMessage_(msg);
    if (item) serialized.push(item);
  });
  return serialized;
}

function threadPayload_(threadId, messageId, subject, messages) {
  var rfc822Ids = [];
  var participants = [];
  messages.forEach(function(item) {
    participants.push(item.from, item.to);
    if (item.rfc822_message_id) rfc822Ids.push(item.rfc822_message_id);
  });
  return {
    gmail_thread_id: threadId,
    gmail_message_id: messageId,
    subject: subject,
    messages: messages,
    rfc822_message_ids: rfc822Ids,
    participant_emails: participants
  };
}

function gmailApiMessagesForThread_(threadId, messageId, gmailMessage) {
  var best = mapGmailMessages_(gmailGet_("threads/" + encodeURIComponent(threadId) + "?format=full"));

  var single = gmailGet_("messages/" + encodeURIComponent(messageId) + "?format=full");
  if (single && single.threadId) {
    var linked = mapGmailMessages_(gmailGet_("threads/" + encodeURIComponent(single.threadId) + "?format=full"));
    if (linked.length > best.length) best = linked;
  }

  var rfc822 = safeMessageValue_(function() { return gmailMessage.getHeader("Message-ID"); });
  rfc822 = String(rfc822 || "").replace(/^<|>$/g, "").trim();
  if (rfc822) {
    var listed = gmailGet_("messages?maxResults=1&q=" + encodeURIComponent("rfc822msgid:" + rfc822));
    var foundId = listed && listed.messages && listed.messages[0] && listed.messages[0].id;
    if (foundId) {
      var found = gmailGet_("messages/" + encodeURIComponent(foundId) + "?format=full");
      if (found && found.threadId) {
        var foundThread = mapGmailMessages_(gmailGet_("threads/" + encodeURIComponent(found.threadId) + "?format=full"));
        if (foundThread.length > best.length) best = foundThread;
      }
    }
  }

  if (best.length) return best;
  return single && single.id ? mapGmailMessages_([single]) : [];
}

function gmailGet_(path) {
  if (!gmailReadonlyGranted_()) return null;
  try {
    var response = UrlFetchApp.fetch("https://gmail.googleapis.com/gmail/v1/users/me/" + path, {
      method: "get",
      muteHttpExceptions: true,
      headers: {Authorization: "Bearer " + ScriptApp.getOAuthToken()}
    });
    if (response.getResponseCode() !== 200) return null;
    return JSON.parse(response.getContentText() || "");
  } catch (err) {
    return null;
  }
}

function mapGmailMessages_(threadOrNull) {
  var list = threadOrNull && threadOrNull.messages ? threadOrNull.messages : threadOrNull;
  if (!list || !list.length) return [];
  return list.map(function(message) {
    var headers = headerMap_(message.payload && message.payload.headers);
    var sentAt = message.internalDate ? new Date(Number(message.internalDate)).toISOString() : new Date().toISOString();
    return {
      gmail_message_id: message.id,
      rfc822_message_id: headers["message-id"] || "",
      from: headers.from || "",
      to: headers.to || "",
      subject: headers.subject || "",
      body: payloadBody_(message.payload, message.id),
      sent_at: sentAt
    };
  }).filter(function(item) { return item.gmail_message_id; });
}

function headerMap_(headers) {
  var map = {};
  (headers || []).forEach(function(header) {
    if (header && header.name) map[String(header.name).toLowerCase()] = header.value || "";
  });
  return map;
}

function payloadBody_(payload, gmailMessageId) {
  var collected = { plain: "", html: "", calendar: "" };
  collectPayload_(payload, collected, gmailMessageId);
  var text = visibleText_(collected.plain) || visibleText_(stripHtml_(collected.html));
  var summary = collected.calendar ? icsSummary_(collected.calendar) : "";
  if (text && summary) return clipBody_(text + "\n\n" + summary);
  return clipBody_(text || summary || "(no body)");
}

function collectPayload_(part, collected, gmailMessageId) {
  if (!part) return;
  var type = String(part.mimeType || "").toLowerCase();
  var filename = String(part.filename || "");
  var decoded = decodeGmailBody_(part.body && part.body.data);
  if (!decoded && part.body && part.body.attachmentId && gmailMessageId) {
    decoded = attachmentText_(gmailMessageId, part.body.attachmentId);
  }
  var calendarPart = type === "text/calendar" || type === "application/ics" || /\.ics$/i.test(filename);
  if (decoded && calendarPart) {
    collected.calendar = collected.calendar || decoded;
  } else if (decoded && type === "text/plain" && !collected.plain) {
    collected.plain = decoded;
  } else if (decoded && type === "text/html" && !collected.html) {
    collected.html = decoded;
  }
  (part.parts || []).forEach(function(child) {
    collectPayload_(child, collected, gmailMessageId);
  });
}

function attachmentText_(messageId, attachmentId) {
  var attachment = gmailGet_(
    "messages/" + encodeURIComponent(messageId) + "/attachments/" + encodeURIComponent(attachmentId)
  );
  return decodeGmailBody_(attachment && attachment.data);
}

function decodeGmailBody_(data) {
  if (!data) return "";
  try {
    var normalized = String(data).replace(/-/g, "+").replace(/_/g, "/");
    while (normalized.length % 4) normalized += "=";
    return Utilities.newBlob(Utilities.base64Decode(normalized)).getDataAsString();
  } catch (err) {
    return "";
  }
}

function serializeCurrentMessage_(msg) {
  try {
    var plain = safeMessageValue_(function() { return visibleText_(msg.getPlainBody()); });
    var body = plain ? clipBody_(plain) : "";
    if (!body) {
      var html = safeMessageValue_(function() { return visibleText_(stripHtml_(msg.getBody())); });
      body = html ? clipBody_(html) : "(no body)";
    }
    return {
      gmail_message_id: msg.getId(),
      rfc822_message_id: safeMessageValue_(function() { return msg.getHeader("Message-ID"); }),
      from: safeMessageValue_(function() { return msg.getFrom(); }),
      to: safeMessageValue_(function() { return msg.getTo(); }),
      subject: safeMessageValue_(function() { return msg.getSubject(); }),
      body: body,
      sent_at: msg.getDate().toISOString()
    };
  } catch (err) {
    return null;
  }
}

function serializeGmailMessage_(msg) {
  try {
    return {
      gmail_message_id: msg.getId(),
      rfc822_message_id: safeMessageValue_(function() { return msg.getHeader("Message-ID"); }),
      from: safeMessageValue_(function() { return msg.getFrom(); }),
      to: safeMessageValue_(function() { return msg.getTo(); }),
      subject: safeMessageValue_(function() { return msg.getSubject(); }),
      body: messageBody_(msg),
      sent_at: msg.getDate().toISOString()
    };
  } catch (err) {
    return null;
  }
}

function messageBody_(msg) {
  var plain = safeMessageValue_(function() { return visibleText_(msg.getPlainBody()); });
  if (plain) return clipBody_(plain);
  var html = safeMessageValue_(function() { return visibleText_(stripHtml_(msg.getBody())); });
  if (html) return clipBody_(html);
  var raw = safeMessageValue_(function() { return bodyFromRaw_(msg.getRawContent()); });
  if (raw) return clipBody_(raw);
  var ics = safeMessageValue_(function() { return bodyFromIcsAttachments_(msg); });
  if (ics) return clipBody_(ics);
  return "(no body)";
}

function safeMessageValue_(fn) {
  try {
    return fn() || "";
  } catch (err) {
    return "";
  }
}

function stripHtml_(html) {
  return String(html || "")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ");
}

function clipBody_(text) {
  text = String(text || "");
  if (text.length <= 20000) return text;
  return text.slice(0, 20000);
}

function bodyFromRaw_(raw) {
  var source = String(raw || "");
  if (!source) return "";
  var calendar = mimePart_(source, "text/calendar") || mimePart_(source, "application/ics");
  var fromCalendar = icsSummary_(calendar);
  if (fromCalendar) return fromCalendar;
  var plain = visibleText_(mimePart_(source, "text/plain"));
  if (plain) return plain;
  return visibleText_(stripHtml_(mimePart_(source, "text/html")));
}

function mimePart_(raw, contentType) {
  var marker = "content-type: " + contentType;
  var lower = raw.toLowerCase();
  var start = lower.indexOf(marker);
  if (start < 0) return "";
  var headerEnd = raw.indexOf("\r\n\r\n", start);
  var sepLength = 4;
  if (headerEnd < 0) {
    headerEnd = raw.indexOf("\n\n", start);
    sepLength = 2;
  }
  if (headerEnd < 0) return "";
  var headers = raw.slice(start, headerEnd);
  var next = lower.indexOf("\r\n--", headerEnd + sepLength);
  if (next < 0) next = lower.indexOf("\n--", headerEnd + sepLength);
  var body = next < 0 ? raw.slice(headerEnd + sepLength) : raw.slice(headerEnd + sepLength, next);
  if (/content-transfer-encoding:\s*quoted-printable/i.test(headers)) {
    body = decodeQuotedPrintable_(body);
  } else if (/content-transfer-encoding:\s*base64/i.test(headers)) {
    try {
      body = Utilities.newBlob(Utilities.base64Decode(body.replace(/\s/g, ""))).getDataAsString();
    } catch (err) {
      body = "";
    }
  }
  return body;
}

function decodeQuotedPrintable_(value) {
  return String(value || "")
    .replace(/=\r?\n/g, "")
    .replace(/=([0-9A-Fa-f]{2})/g, function(_, hex) {
      return String.fromCharCode(parseInt(hex, 16));
    });
}

function bodyFromIcsAttachments_(msg) {
  var files = msg.getAttachments({includeInlineImages: false, includeAttachments: true}) || [];
  var text = "";
  files.forEach(function(file) {
    if (text) return;
    var name = String(file.getName() || "");
    var type = String(file.getContentType() || "");
    if (!/\.ics$/i.test(name) && type.indexOf("calendar") === -1 && type.indexOf("ics") === -1) return;
    text = icsSummary_(file.getDataAsString());
  });
  return text;
}

function icsSummary_(ics) {
  var fields = icsFields_(ics);
  if (!fields.SUMMARY && !fields.DESCRIPTION && !fields.LOCATION) return "";
  var lines = [];
  if (fields.STATUS) lines.push(fields.STATUS);
  if (fields.SUMMARY) lines.push(fields.SUMMARY);
  var when = formatIcsDate_(fields.DTSTART);
  var end = formatIcsDate_(fields.DTEND);
  if (when && end) lines.push(when + " – " + end);
  else if (when) lines.push(when);
  if (fields.LOCATION) lines.push(fields.LOCATION);
  if (fields.DESCRIPTION) lines.push(fields.DESCRIPTION);
  return visibleText_(lines.join("\n"));
}

function icsFields_(ics) {
  var fields = {};
  String(ics || "").replace(/\r\n[ \t]/g, "").replace(/\n[ \t]/g, "").split(/\r?\n/).forEach(function(line) {
    var split = line.indexOf(":");
    if (split < 1) return;
    var name = line.slice(0, split).split(";")[0].toUpperCase();
    if (!fields[name]) fields[name] = line.slice(split + 1).replace(/\\n/g, "\n").replace(/\\,/g, ",");
  });
  return fields;
}

function formatIcsDate_(value) {
  var match = String(value || "").match(/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})/);
  if (!match) return visibleText_(value);
  return match[1] + "-" + match[2] + "-" + match[3] + " " + match[4] + ":" + match[5];
}

function visibleText_(value) {
  return String(value || "")
    .replace(/[\u00a0\u200b\u200c\u200d\ufeff]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
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

function dateFormValue_(e, fieldName) {
  var formInputs = e.commonEventObject && e.commonEventObject.formInputs;
  if (formInputs && formInputs[fieldName] && formInputs[fieldName].dateInput) {
    var ms = formInputs[fieldName].dateInput.msSinceEpoch;
    if (ms !== undefined && ms !== null && ms !== "") {
      return new Date(Number(ms));
    }
  }
  return null;
}

function switchFormValue_(e, fieldName, expectedValue) {
  expectedValue = expectedValue || "true";
  var formInputs = e.commonEventObject && e.commonEventObject.formInputs;
  if (formInputs && formInputs[fieldName]) {
    var field = formInputs[fieldName];
    var bucket = field.stringInputs || (field[""] && field[""].stringInputs);
    if (bucket && bucket.value && bucket.value.length) {
      return bucket.value.indexOf(expectedValue) !== -1;
    }
  }
  return false;
}

function formatDateForApi_(date) {
  if (!date) {
    return null;
  }
  return Utilities.formatDate(date, "GMT", "yyyy-MM-dd");
}

function parseIsoDateMs_(iso) {
  if (!iso) {
    return null;
  }
  var date = new Date(iso);
  return isNaN(date.getTime()) ? null : date.getTime();
}

function dealActionParams_(deal) {
  return {
    deal_id: String(deal.id),
    workspace_id: String(deal.workspace_id)
  };
}

function pipelineStagesForDeal_(context, deal) {
  var workspace = findById_(context.workspaces || [], deal.workspace_id);
  if (!workspace) {
    return [];
  }
  var pipeline = findById_(workspace.pipelines || [], deal.pipeline_id);
  if (!pipeline) {
    return [];
  }
  return pipeline.stages || [];
}

function findLinkedDeal_(e) {
  var dealId = e.parameters && e.parameters.deal_id;
  if (!dealId) {
    throw new Error("Missing deal.");
  }
  var threadData = readOpenThread_(e);
  var status = threadStatus_(threadData);
  var deal = (status.linked || []).filter(function(item) {
    return String(item.id) === String(dealId);
  })[0];
  if (!deal) {
    throw new Error("Deal not found for this thread.");
  }
  return { threadData: threadData, deal: deal, status: status };
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
  var tasks = deal.tasks && deal.tasks.length ?
    deal.tasks :
    (deal.next_task ? [deal.next_task] : []);
  tasks.forEach(function(task) {
    var taskText = task.title;
    if (task.due_on) {
      taskText += " (due " + formatIsoDate_(task.due_on) + ")";
    }
    addDealField_(section, "Task", taskText);
    if (task.id) {
      section.addWidget(
        CardService.newTextButton()
          .setText("Edit task")
          .setOnClickAction(
            CardService.newAction()
              .setFunctionName("showEditTask")
              .setParameters(
                Object.assign({}, dealActionParams_(deal), { task_id: String(task.id) })
              )
          )
      );
    }
  });
  if (deal.products && deal.products.length) {
    addDealField_(section, "Products", deal.products.join("\n"));
  }
  var params = dealActionParams_(deal);
  section.addWidget(
    CardService.newTextButton()
      .setText("Edit deal")
      .setOnClickAction(
        CardService.newAction().setFunctionName("showEditDeal").setParameters(params)
      )
  );
  section.addWidget(
    CardService.newTextButton()
      .setText("Add note")
      .setOnClickAction(
        CardService.newAction().setFunctionName("showAddNote").setParameters(params)
      )
  );
  section.addWidget(
    CardService.newTextButton()
      .setText("Add task")
      .setOnClickAction(
        CardService.newAction().setFunctionName("showAddTask").setParameters(params)
      )
  );
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
  var matchedCompany = companyForOpenMessage_(threadData, status);
  var companyInput = CardService.newTextInput()
    .setFieldName("company_name")
    .setTitle("Company")
    .setHint("Existing company, or a new name to confirm");
  if (matchedCompany) {
    companyInput.setValue(matchedCompany.name);
  }
  createSection.addWidget(companyInput);
  var suggestedCompanies = (status && status.suggested_companies) || [];
  if (!suggestedCompanies.length && matchedCompany) {
    suggestedCompanies = [ matchedCompany ];
  }
  suggestedCompanies = suggestedCompanies.filter(function(company) {
    return !matchedCompany || String(company.id) !== String(matchedCompany.id);
  });
  suggestedCompanies.forEach(function(company) {
    var label = company.domain ? company.name + " (" + company.domain + ")" : company.name;
    createSection.addWidget(
      CardService.newTextButton()
        .setText("Use " + label)
        .setOnClickAction(
          CardService.newAction()
            .setFunctionName("createDealFromThread")
            .setParameters({
              gmail_thread_id: threadData.gmail_thread_id,
              company_id: String(company.id)
            })
        )
    );
  });
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
  return refreshThreadCardFromEdit_(e, message, false);
}

function refreshThreadCardFromEdit_(e, message, popToRoot) {
  var threadData = readOpenThread_(e);
  var status = threadStatus_(threadData);
  applyLinkedWorkspace_(status);
  var context = creamContext_();
  var navigation = CardService.newNavigation();
  if (popToRoot !== false) {
    navigation = navigation.popToRoot();
  }
  navigation = navigation.updateCard(buildThreadCard_(threadData, status, context));
  var builder = CardService.newActionResponseBuilder().setNavigation(navigation);
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
    var dealName = formValue_(e, "deal_name") || e.parameters.deal_name || threadData.subject || "Deal from email";
    var destination = resolveDestination_(creamContext_());
    var newDeal = { name: dealName, pipeline_stage_id: Number(destination.stage.id) };
    var companyId = e.parameters.company_id;
    if (companyId) {
      newDeal.company_id = Number(companyId);
    } else {
      var companyName = formValue_(e, "company_name") || e.parameters.company_name;
      if (companyName && String(companyName).trim()) {
        newDeal.company_name = String(companyName).trim();
      }
      if (e.parameters.create_company === "true") {
        newDeal.create_company = true;
      } else if (!companyId) {
        var confirmation = companyConfirmationCard_(threadData, dealName, newDeal.company_name);
        if (confirmation) {
          return confirmation;
        }
      }
    }
    var result = creamThreadLink_({
      new_deal: newDeal,
      thread: {
        gmail_thread_id: threadData.gmail_thread_id,
        messages: threadData.messages
      }
    });
    return refreshThreadCardAfterLink_(
      e,
      "Imported " + result.imported_count + " message(s)."
    );
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}

function companyConfirmationCard_(threadData, dealName, companyName) {
  var domain = externalCompanyDomain_(threadData);
  var matches = [];
  if (companyName) {
    matches = matches.concat(creamSearchCompanies_(companyName) || []);
  }
  if (domain && domain !== companyName) {
    matches = matches.concat(creamSearchCompanies_(domain) || []);
  }
  var seen = {};
  matches = matches.filter(function(company) {
    if (seen[company.id]) return false;
    seen[company.id] = true;
    return true;
  });
  var exact = matches.filter(function(company) {
    return companyName && String(company.name).toLowerCase() === String(companyName).toLowerCase();
  })[0];
  if (exact) {
    return null;
  }
  if (!companyName && !domain && !(matches || []).length) {
    throw new Error("Company is required.");
  }

  var proposed = companyName || domainLabel_(domain) || "Unknown company";
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle("Company"));
  var section = CardService.newCardSection();
  var prompt = "No company named \"" + proposed + "\".";
  if (domain) {
    prompt += " Create it with email domain " + domain + "?";
  } else {
    prompt += " Create it?";
  }
  section.addWidget(CardService.newTextParagraph().setText(prompt));
  section.addWidget(
    CardService.newTextButton()
      .setText("Create \"" + proposed + "\"")
      .setOnClickAction(
        CardService.newAction()
          .setFunctionName("createDealFromThread")
          .setParameters({
            gmail_thread_id: threadData.gmail_thread_id,
            deal_name: dealName,
            company_name: proposed,
            create_company: "true"
          })
      )
  );
  (matches || []).filter(function(company) {
    return !exact || company.id !== exact.id;
  }).slice(0, 5).forEach(function(company) {
    var label = company.domain ? company.name + " (" + company.domain + ")" : company.name;
    section.addWidget(
      CardService.newTextButton()
        .setText("Use " + label)
        .setOnClickAction(
          CardService.newAction()
            .setFunctionName("createDealFromThread")
            .setParameters({
              gmail_thread_id: threadData.gmail_thread_id,
              deal_name: dealName,
              company_id: String(company.id)
            })
        )
    );
  });
  card.addSection(section);
  return CardService.newActionResponseBuilder()
    .setNavigation(CardService.newNavigation().pushCard(card.build()))
    .build();
}

function companyForOpenMessage_(threadData, status) {
  var domain = openMessageDomain_(threadData) || externalCompanyDomain_(threadData);
  if (!domain) return null;
  var suggested = (status && status.suggested_companies) || [];
  var exact = suggested.filter(function(company) {
    return domainsMatch_(company.domain, domain);
  })[0];
  if (exact) return exact;
  var found = creamSearchCompanies_(domain) || [];
  return found.filter(function(company) {
    return domainsMatch_(company.domain, domain);
  })[0] || null;
}

function openMessageDomain_(threadData) {
  var current = (threadData.messages || []).filter(function(message) {
    return message.gmail_message_id === threadData.gmail_message_id;
  })[0];
  return domainFromRaw_(current && current.from);
}

function domainFromRaw_(raw) {
  if (!raw) return null;
  var domain = null;
  String(raw).split(/[,;]/).forEach(function(part) {
    if (domain) return;
    var match = String(part).match(/<([^>]+)>/);
    var email = (match ? match[1] : part).trim().toLowerCase();
    var at = email.lastIndexOf("@");
    if (at < 1) return;
    var candidate = normalizeDomain_(email.slice(at + 1));
    if (candidate && !freeEmailDomain_(candidate)) domain = candidate;
  });
  return domain;
}

function normalizeDomain_(domain) {
  return String(domain || "").trim().toLowerCase().replace(/^www\./, "");
}

function domainsMatch_(stored, emailDomain) {
  var left = normalizeDomain_(stored);
  var right = normalizeDomain_(emailDomain);
  return !!left && !!right && left === right;
}

function externalCompanyDomain_(threadData) {
  var domain = null;
  (threadData.messages || []).forEach(function(message) {
    if (domain) return;
    domain = domainFromRaw_(message.from) || domainFromRaw_(message.to);
  });
  return domain;
}

function freeEmailDomain_(domain) {
  return [
    "gmail.com", "googlemail.com", "hotmail.com", "outlook.com", "live.com",
    "yahoo.com", "yahoo.es", "icloud.com", "me.com", "proton.me", "protonmail.com", "aol.com"
  ].indexOf(String(domain || "").toLowerCase()) !== -1;
}

function domainLabel_(domain) {
  if (!domain) return "";
  var label = String(domain).split(".")[0];
  return label ? label.charAt(0).toUpperCase() + label.slice(1) : "";
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

function buildEditDealCard_(deal, context) {
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle("Edit deal"));
  var section = CardService.newCardSection().setHeader(deal.name);
  var stages = pipelineStagesForDeal_(context, deal);
  if (stages.length) {
    var stageInput = CardService.newSelectionInput()
      .setType(CardService.SelectionInputType.DROPDOWN)
      .setFieldName("pipeline_stage_id")
      .setTitle("Stage");
    stages.forEach(function(stage) {
      stageInput.addItem(
        stage.name,
        String(stage.id),
        String(stage.id) === String(deal.pipeline_stage_id)
      );
    });
    section.addWidget(stageInput);
  }
  var valueInput = CardService.newTextInput()
    .setFieldName("deal_value")
    .setTitle("Value");
  if (deal.value !== undefined && deal.value !== null) {
    valueInput.setValue(String(deal.value));
  }
  section.addWidget(valueInput);
  var closePicker = CardService.newDatePicker()
    .setFieldName("expected_close_date")
    .setTitle("Close date");
  var closeMs = parseIsoDateMs_(deal.expected_close_date);
  if (closeMs) {
    closePicker.setValueInMsSinceEpoch(closeMs);
  }
  section.addWidget(closePicker);
  var params = dealActionParams_(deal);
  section.addWidget(
    CardService.newTextButton()
      .setText("Save")
      .setOnClickAction(
        CardService.newAction().setFunctionName("saveEditDeal").setParameters(params)
      )
  );
  card.addSection(section);
  return card.build();
}

function showEditDeal(e) {
  try {
    var found = findLinkedDeal_(e);
    var context = creamContext_();
    return CardService.newActionResponseBuilder()
      .setNavigation(
        CardService.newNavigation().pushCard(buildEditDealCard_(found.deal, context))
      )
      .build();
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}

function saveEditDeal(e) {
  try {
    var dealId = e.parameters.deal_id;
    var workspaceId = e.parameters.workspace_id;
    var payload = {};
    var stageId = formValue_(e, "pipeline_stage_id");
    if (stageId) {
      payload.pipeline_stage_id = Number(stageId);
    }
    var valueStr = formValue_(e, "deal_value");
    if (valueStr !== null && valueStr !== "") {
      payload.value = Number(valueStr);
    }
    var closeDate = dateFormValue_(e, "expected_close_date");
    if (closeDate) {
      payload.expected_close_date = formatDateForApi_(closeDate);
    }
    creamUpdateDeal_(dealId, payload, workspaceId);
    return refreshThreadCardFromEdit_(e, "Deal updated");
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}

function buildAddNoteCard_(deal) {
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle("Add note"));
  var section = CardService.newCardSection().setHeader(deal.name);
  section.addWidget(
    CardService.newTextInput().setFieldName("note_title").setTitle("Title (optional)")
  );
  section.addWidget(
    CardService.newTextInput()
      .setFieldName("note_body")
      .setTitle("Note")
      .setMultiline(true)
  );
  section.addWidget(
    CardService.newTextButton()
      .setText("Save note")
      .setOnClickAction(
        CardService.newAction()
          .setFunctionName("saveAddNote")
          .setParameters(dealActionParams_(deal))
      )
  );
  card.addSection(section);
  return card.build();
}

function showAddNote(e) {
  try {
    var found = findLinkedDeal_(e);
    return CardService.newActionResponseBuilder()
      .setNavigation(
        CardService.newNavigation().pushCard(buildAddNoteCard_(found.deal))
      )
      .build();
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}

function saveAddNote(e) {
  try {
    var dealId = e.parameters.deal_id;
    var workspaceId = e.parameters.workspace_id;
    var body = formValue_(e, "note_body");
    if (!body || !String(body).trim()) {
      throw new Error("Note text is required.");
    }
    var notePayload = { body: String(body).trim() };
    var title = formValue_(e, "note_title");
    if (title && String(title).trim()) {
      notePayload.title = String(title).trim();
    }
    creamCreateDealNote_(dealId, notePayload, workspaceId);
    return refreshThreadCardFromEdit_(e, "Note added");
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}

function buildAddTaskCard_(deal) {
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle("Add task"));
  var section = CardService.newCardSection().setHeader(deal.name);
  section.addWidget(
    CardService.newTextInput().setFieldName("task_title").setTitle("Task title")
  );
  var tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  section.addWidget(
    CardService.newDatePicker()
      .setFieldName("task_due_on")
      .setTitle("Due date")
      .setValueInMsSinceEpoch(tomorrow.getTime())
  );
  section.addWidget(
    CardService.newTextButton()
      .setText("Save task")
      .setOnClickAction(
        CardService.newAction()
          .setFunctionName("saveAddTask")
          .setParameters(dealActionParams_(deal))
      )
  );
  card.addSection(section);
  return card.build();
}

function showAddTask(e) {
  try {
    var found = findLinkedDeal_(e);
    return CardService.newActionResponseBuilder()
      .setNavigation(
        CardService.newNavigation().pushCard(buildAddTaskCard_(found.deal))
      )
      .build();
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}

function saveAddTask(e) {
  try {
    var dealId = e.parameters.deal_id;
    var workspaceId = e.parameters.workspace_id;
    var title = formValue_(e, "task_title");
    if (!title || !String(title).trim()) {
      throw new Error("Task title is required.");
    }
    var payload = {
      title: String(title).trim(),
      taskable_type: "Deal",
      taskable_id: Number(dealId)
    };
    var dueOn = dateFormValue_(e, "task_due_on");
    if (dueOn) {
      payload.due_on = formatDateForApi_(dueOn);
    }
    creamCreateTask_(payload, workspaceId);
    return refreshThreadCardFromEdit_(e, "Task added");
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}

function findTaskOnDeal_(deal, taskId) {
  var tasks = deal.tasks && deal.tasks.length ?
    deal.tasks :
    (deal.next_task ? [deal.next_task] : []);
  return tasks.filter(function(task) {
    return String(task.id) === String(taskId);
  })[0] || null;
}

function buildEditTaskCard_(deal, task) {
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle("Edit task"));
  var section = CardService.newCardSection().setHeader(deal.name);
  section.addWidget(
    CardService.newTextInput()
      .setFieldName("task_title")
      .setTitle("Task title")
      .setValue(task.title || "")
  );
  var duePicker = CardService.newDatePicker().setFieldName("task_due_on").setTitle("Due date");
  var dueMs = parseIsoDateMs_(task.due_on);
  if (dueMs) {
    duePicker.setValueInMsSinceEpoch(dueMs);
  }
  section.addWidget(duePicker);
  section.addWidget(
    CardService.newDecoratedText()
      .setTopLabel("Completed")
      .setText("Mark this task as done")
      .setWrapText(true)
      .setSwitchControl(
        CardService.newSwitch()
          .setFieldName("task_completed")
          .setValue("true")
          .setSelected(task.completed === true)
      )
  );
  var params = Object.assign({}, dealActionParams_(deal), { task_id: String(task.id) });
  section.addWidget(
    CardService.newTextButton()
      .setText("Save task")
      .setOnClickAction(
        CardService.newAction().setFunctionName("saveEditTask").setParameters(params)
      )
  );
  card.addSection(section);
  return card.build();
}

function showEditTask(e) {
  try {
    var found = findLinkedDeal_(e);
    var taskId = e.parameters.task_id;
    var task = findTaskOnDeal_(found.deal, taskId);
    if (!task) {
      throw new Error("Task not found.");
    }
    return CardService.newActionResponseBuilder()
      .setNavigation(
        CardService.newNavigation().pushCard(buildEditTaskCard_(found.deal, task))
      )
      .build();
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}

function saveEditTask(e) {
  try {
    var taskId = e.parameters.task_id;
    var workspaceId = e.parameters.workspace_id;
    var title = formValue_(e, "task_title");
    if (!title || !String(title).trim()) {
      throw new Error("Task title is required.");
    }
    var payload = { title: String(title).trim() };
    var dueOn = dateFormValue_(e, "task_due_on");
    if (dueOn) {
      payload.due_on = formatDateForApi_(dueOn);
    }
    payload.completed = switchFormValue_(e, "task_completed");
    creamUpdateTask_(taskId, payload, workspaceId);
    return refreshThreadCardFromEdit_(e, "Task updated");
  } catch (err) {
    return CardService.newActionResponseBuilder()
      .setNotification(CardService.newNotification().setText(String(err.message)))
      .build();
  }
}
