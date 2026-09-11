module McpHelpers
  def call_tool(name, arguments, id: 99, token: plaintext)
    post mcp_url,
      params: { jsonrpc: "2.0", id: id, method: "tools/call",
                params: { name: name, arguments: arguments } },
      as: :json, headers: mcp_headers(token)

    expect(response).to have_http_status(:success)
    JSON.parse(JSON.parse(response.body).dig("result", "content", 0, "text"))
  end

  def call_tool_raw(name, arguments, id: 99, token: plaintext)
    post mcp_url,
      params: { jsonrpc: "2.0", id: id, method: "tools/call",
                params: { name: name, arguments: arguments } },
      as: :json, headers: mcp_headers(token)

    response
  end

  def mcp_tool_error(name, arguments, token: plaintext)
    body = JSON.parse(call_tool_raw(name, arguments, token: token).body)
    JSON.parse(body.dig("result", "content", 0, "text"))
  end

  def mcp_headers(token)
    {
      "Authorization" => "Bearer #{token}",
      "Accept" => "application/json",
      "Host" => "localhost"
    }
  end

  def initialize_payload
    {
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: MCP::Configuration::LATEST_STABLE_PROTOCOL_VERSION,
        capabilities: {},
        clientInfo: { name: "test", version: "1.0" }
      }
    }
  end

  def tools_list_payload
    { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} }
  end

  def api_token_for(user, workspace)
    token = user.api_tokens.create!(name: "Test MCP", workspace: workspace)
    token.plaintext_token
  end
end

RSpec.configure do |config|
  config.include McpHelpers, type: :request
end
