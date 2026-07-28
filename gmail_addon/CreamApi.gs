/**
 * HTTP helpers for the CReaM REST API v1.
 */
var CREAM_WORKSPACE_KEY = "cream.workspace_id";

function getSelectedWorkspaceId_() {
  return PropertiesService.getUserProperties().getProperty(CREAM_WORKSPACE_KEY);
}

function setSelectedWorkspaceId_(workspaceId) {
  if (workspaceId) {
    PropertiesService.getUserProperties().setProperty(CREAM_WORKSPACE_KEY, String(workspaceId));
  } else {
    PropertiesService.getUserProperties().deleteProperty(CREAM_WORKSPACE_KEY);
  }
}

function creamApiRequest_(method, path, payload) {
  var token = getCreamAccessToken_();
  var url = getCreamBaseUrl_() + path;
  var headers = {
    Authorization: "Bearer " + token,
    Accept: "application/json",
    "Content-Type": "application/json"
  };
  var workspaceId = getSelectedWorkspaceId_();
  if (workspaceId) {
    headers["X-Cream-Workspace-Id"] = workspaceId;
  }
  var options = {
    method: method,
    muteHttpExceptions: true,
    headers: headers
  };

  if (payload) {
    options.payload = JSON.stringify(payload);
  }

  var response = UrlFetchApp.fetch(url, options);
  var code = response.getResponseCode();
  var body = response.getContentText();

  if (code === 401) {
    clearCreamAuth_();
    throw new Error("not_connected");
  }

  if (code >= 400) {
    throw new Error("CReaM API error " + code + ": " + body);
  }

  return body ? JSON.parse(body) : {};
}

function creamThreadStatus_(threadPayload) {
  return creamApiRequest_("post", "/api/v1/gmail/threads/status", threadPayload);
}

function creamContext_() {
  return creamApiRequest_("get", "/api/v1/gmail/context");
}

function creamThreadLink_(payload) {
  return creamApiRequest_("post", "/api/v1/gmail/threads/link", payload);
}

function creamSearchDeals_(query) {
  var encoded = encodeURIComponent(query || "");
  return creamApiRequest_("get", "/api/v1/deals?q=" + encoded);
}
