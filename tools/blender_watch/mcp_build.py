"""Send the durable build to a running Blender via the real stdio MCP server."""
import argparse,asyncio,json,os,shutil
from pathlib import Path
from datetime import timedelta
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client
async def main():
 p=argparse.ArgumentParser();p.add_argument('--server',default=shutil.which('mcp-for-blender'));p.add_argument('--goal',required=True);args=p.parse_args()
 if not args.server:p.error('Install mcp-for-blender or pass --server /path/to/mcp-for-blender')
 build=Path(__file__).resolve().with_name('build_watch.py')
 code=f"p={json.dumps(str(build))}\nexec(compile(open(p).read(),p,'exec'),{{'__file__':p,'__name__':'__main__'}})"
 env=dict(os.environ,BLENDER_HOST='127.0.0.1',BLENDER_MCP_DISABLE_TELEMETRY='true',DISABLE_TELEMETRY='true')
 async with stdio_client(StdioServerParameters(command=args.server,env=env)) as (reader,writer):
  async with ClientSession(reader,writer,read_timeout_seconds=timedelta(seconds=240)) as session:
   await session.initialize();result=await session.call_tool('execute_blender_code',{'code':code,'user_prompt':args.goal})
   texts=[c.text for c in result.content if c.type=='text']
   for t in texts:print(t)
   if result.isError or not any('DN_WATCH_BUILD' in t for t in texts):raise RuntimeError('Blender did not confirm a successful build')
if __name__=='__main__':asyncio.run(main())
