/**
 * OAuth2 client for the CReaM API (Doorkeeper authorization code + PKCE).
 * Uses the official apps-script-oauth2 library and its /usercallback endpoint.
 */
var CREAM_PROP_BASE_URL = "CREAM_BASE_URL";
var CREAM_PROP_CLIENT_ID = "CREAM_CLIENT_ID";

function getCreamBaseUrl_() {
  var url = PropertiesService.getScriptProperties().getProperty(CREAM_PROP_BASE_URL);
  if (!url) {
    throw new Error("Set Script Property CREAM_BASE_URL (e.g. https://crm.example.com)");
  }
  return url.replace(/\/$/, "");
}

function getCreamClientId_() {
  var clientId = PropertiesService.getScriptProperties().getProperty(CREAM_PROP_CLIENT_ID);
  if (!clientId) {
    throw new Error("Set Script Property CREAM_CLIENT_ID from POST /oauth/register");
  }
  return clientId;
}

function stripEmptyClientSecretFromTokenPayload_(payload) {
  if (payload && (payload.client_secret === "" || payload.client_secret === null)) {
    delete payload.client_secret;
  }
  return payload;
}

function getCreamOAuthService_() {
  return OAuth2.createService("cream")
    .setAuthorizationBaseUrl(getCreamBaseUrl_() + "/oauth/authorize")
    .setTokenUrl(getCreamBaseUrl_() + "/oauth/token")
    .setClientId(getCreamClientId_())
    .setScope("api")
    .setCallbackFunction("authCallback")
    .setPropertyStore(PropertiesService.getUserProperties())
    .setCache(CacheService.getUserCache())
    .setLock(LockService.getUserLock())
    .setParam("access_type", "offline")
    .setParam("prompt", "consent")
    .setTokenPayloadHandler(stripEmptyClientSecretFromTokenPayload_);
}

function getCreamRedirectUri_() {
  return getCreamOAuthService_().getRedirectUri();
}

/** Run once to print the exact callback URI to register in CReaM. */
function logCreamRedirectUri() {
  var uri = getCreamRedirectUri_();
  Logger.log("OAuth redirect_uri: " + uri);
  return uri;
}

function getCreamAuthorizationUrl_() {
  var service = getCreamOAuthService_();
  service.generateCodeVerifier();
  return service.getAuthorizationUrl();
}

function clearCreamAuth_() {
  getCreamOAuthService_().reset();
}

function hasCreamAccess_() {
  return getCreamOAuthService_().hasAccess();
}

function getCreamAccessToken_() {
  var service = getCreamOAuthService_();
  if (!service.hasAccess()) {
    throw new Error("not_connected");
  }
  return service.getAccessToken();
}

/** Refreshes the stored OAuth token. Returns true on success, false otherwise. */
function refreshCreamAccessToken_() {
  var service = getCreamOAuthService_();
  var token = service.getToken();
  if (!token || !token.refresh_token) {
    return false;
  }
  try {
    service.refresh();
    return service.hasAccess();
  } catch (err) {
    return false;
  }
}

function buildConnectCard_() {
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle("CReaM"));

  var section = CardService.newCardSection()
    .addWidget(
      CardService.newTextParagraph().setText(
        "Connect your CReaM account to link Gmail threads to deals."
      )
    );

  try {
    section.addWidget(
      CardService.newTextButton()
        .setText("Connect with CReaM")
        .setOpenLink(
          CardService.newOpenLink().setUrl(getCreamAuthorizationUrl_())
        )
    );
  } catch (err) {
    section.addWidget(
      CardService.newTextParagraph().setText(String(err.message))
    );
  }

  card.addSection(section);
  return card.build();
}

function buildConnectedHomeCard_() {
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle("CReaM"));

  var section = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph().setText("Connected to CReaM."))
    .addWidget(
      CardService.newTextButton()
        .setText("Disconnect")
        .setOnClickAction(
          CardService.newAction().setFunctionName("disconnectCream")
        )
    );

  card.addSection(section);
  return card.build();
}

function onHomepage() {
  var authCard = gmailAuthorizationCard_();
  if (authCard) return [ authCard ];
  if (!hasCreamAccess_()) {
    return [ buildConnectCard_() ];
  }
  return [ buildConnectedHomeCard_() ];
}

var GMAIL_READONLY_SCOPE_ = "https://www.googleapis.com/auth/gmail.readonly";

function gmailReadonlyGranted_() {
  var info = ScriptApp.getAuthorizationInfo(ScriptApp.AuthMode.FULL, [GMAIL_READONLY_SCOPE_]);
  return info.getAuthorizationStatus() === ScriptApp.AuthorizationStatus.NOT_REQUIRED;
}

/** Card shown when gmail.readonly is missing. Calling Gmail or ScriptApp.getOAuthToken() without it aborts with an uncaught authorization page. */
function gmailAuthorizationCard_() {
  var info = ScriptApp.getAuthorizationInfo(ScriptApp.AuthMode.FULL, [GMAIL_READONLY_SCOPE_]);
  if (info.getAuthorizationStatus() === ScriptApp.AuthorizationStatus.NOT_REQUIRED) {
    return null;
  }
  var url = info.getAuthorizationUrl();
  var section = CardService.newCardSection().addWidget(
    CardService.newTextParagraph().setText(
      "CReaM needs permission to read this email thread. Choose Authorize and accept the Google prompt, then return to Gmail."
    )
  );
  if (url) {
    section.addWidget(
      CardService.newTextButton()
        .setText("Authorize")
        .setAuthorizationAction(CardService.newAuthorizationAction().setAuthorizationUrl(url))
    );
  }
  return CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader().setTitle("CReaM"))
    .addSection(section)
    .build();
}

function authorizeGmailAccess() {
  ScriptApp.requireScopes(ScriptApp.AuthMode.FULL, [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.addons.current.message.readonly"
  ]);
  Gmail.Users.getProfile("me");
}

function authCallback(request) {
  var authorized = getCreamOAuthService_().handleCallback(request);
  var message = authorized
    ? "<p><strong>Connected to CReaM.</strong></p><p>You can close this tab and return to Gmail.</p>"
    : "<p>Authorization denied. Close this tab and try again from Gmail.</p>";
  return HtmlService.createHtmlOutput(message).setTitle("CReaM");
}

function disconnectCream() {
  clearCreamAuth_();
  return CardService.newActionResponseBuilder()
    .setNavigation(CardService.newNavigation().updateCard(buildConnectCard_()))
    .build();
}
