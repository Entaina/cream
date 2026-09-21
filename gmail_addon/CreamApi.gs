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

function creamApiFetch_(method, path, payload, accessToken) {
  var url = getCreamBaseUrl_() + path;
  var headers = {
    Authorization: "Bearer " + accessToken,
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
  return {
    code: response.getResponseCode(),
    body: response.getContentText()
  };
}

function creamApiRequest_(method, path, payload) {
  var token = getCreamAccessToken_();
  var result = creamApiFetch_(method, path, payload, token);

  if (result.code === 401 && refreshCreamAccessToken_()) {
    token = getCreamAccessToken_();
    result = creamApiFetch_(method, path, payload, token);
  }

  if (result.code === 401) {
    clearCreamAuth_();
    throw new Error("not_connected");
  }

  if (result.code >= 400) {
    throw new Error("CReaM API error " + result.code + ": " + result.body);
  }

  return result.body ? JSON.parse(result.body) : {};
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
