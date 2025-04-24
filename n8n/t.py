from fastmcp import FastMCP
from fastmcp.transports.sse import SseServerTransport
from fastmcp.types import TextContent
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from starlette.responses import StreamingResponse
import uvicorn

app = FastAPI()
mcp_server = FastMCP(title="SSE Demo Server")

# 1. 创建 SSE 传输层
sse_transport = SseServerTransport(
    path="/sse",
    keep_alive_interval=15,
    retry_delay=3000
)

# 2. 定义一个工具函数
@mcp_server.tool("echo")
async def echo_handler(arguments: dict) -> list[TextContent]:
    """简单的回显工具"""
    message = arguments.get("message", "")
    return [TextContent(type="text", text=f"Server response: {message}")]

# 3. SSE 端点（使用 StreamingResponse 返回流）
@app.get(sse_transport.path)
async def sse_endpoint(request: Request):
    """建立 SSE 连接的端点"""
    async def generator():
        async for message in sse_transport.stream(request.scope):
            yield message
    return StreamingResponse(generator(), media_type="text/event-stream")

# 4. POST 消息触发处理
@app.post("/send")
async def send_message(request: Request):
    """接收客户端消息并触发 MCP 处理"""
    data = await request.json()

    # 获取当前连接上下文（已连接的 SSE 客户端）
    streams = sse_transport.get_active_streams()
    if not streams:
        return {"status": "No active connection"}

    # 将数据广播给所有连接的客户端
    for receive_stream, send_stream in streams:
        await mcp_server.run(
            receive_stream=None,  # 这里只使用发送
            send_stream=send_stream,
            initialization_options=mcp_server.create_initialization_options(
                name=data.get("name"),
                arguments=data.get("arguments")
            )
        )

    return {"status": "Message processed"}

# 5. 前端测试页面
@app.get("/", response_class=HTMLResponse)
async def test_page():
    return """
    <html>
    <head><title>FastMCP SSE Demo</title></head>
    <body>
        <h1>FastMCP SSE Demo</h1>

        <div id="messages" style="height: 300px; overflow-y: scroll; border: 1px solid #ccc; padding: 10px;"></div>

        <input type="text" id="messageInput" placeholder="Enter message">
        <button onclick="sendMessage()">Send</button>

        <div id="status">Status: Not connected</div>

        <script>
            let eventSource;
            const messageInput = document.getElementById('messageInput');
            const messagesDiv = document.getElementById('messages');
            const statusDiv = document.getElementById('status');

            function connectSSE() {
                statusDiv.textContent = "Status: Connecting...";

                eventSource = new EventSource('/sse');

                eventSource.onopen = () => {
                    statusDiv.textContent = "Status: Connected";
                    statusDiv.style.color = 'green';
                };

                eventSource.onmessage = (e) => {
                    try {
                        const data = JSON.parse(e.data);
                        if (data.type === "text") {
                            messagesDiv.innerHTML += `<p>${new Date().toLocaleTimeString()}: ${data.text}</p>`;
                            messagesDiv.scrollTop = messagesDiv.scrollHeight;
                        }
                    } catch (err) {
                        console.error("Error parsing message:", err);
                    }
                };

                eventSource.onerror = () => {
                    statusDiv.textContent = "Status: Disconnected";
                    statusDiv.style.color = 'red';
                    setTimeout(connectSSE, 3000); // 自动重连
                };
            }

            function sendMessage() {
                const message = messageInput.value.trim();
                if (message) {
                    fetch('/send', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            name: "echo",
                            arguments: { message }
                        })
                    });
                    messageInput.value = '';
                }
            }

            messageInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') sendMessage();
            });

            connectSSE();
        </script>
    </body>
    </html>
    """

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
