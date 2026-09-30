"""Run one reviewed reference step against an already connected Blender addon."""
import argparse
import asyncio
import os
from pathlib import Path

STEPS = ("create", "refine-hands", "finish-hands", "rig", "animate", "export-wave", "preview-wave")
ROOT = Path(__file__).resolve().parent


async def run(args):
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client

    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    code = f"OUTPUT_DIR = {str(output)!r}\nRENDER_PREVIEWS = {not args.skip_renders!r}\n"
    code += (ROOT / "steps" / f"{args.step}.py").read_text()
    params = StdioServerParameters(
        command=args.server,
        args=[],
        env={**os.environ, "BLENDER_MCP_DISABLE_TELEMETRY": "true"},
    )
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool(
                "execute_blender_code",
                {"code": code, "user_prompt": f"Run the Agentnagar humanoid reference step: {args.step}"},
            )
            messages = [item.text for item in result.content if item.type == "text"]
            for message in messages:
                print(message)
            # This community server can report Python failures as plain text.
            if result.isError or not any(message.startswith("Code executed successfully:") for message in messages):
                raise RuntimeError("Blender step did not report successful execution")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("step", choices=STEPS)
    parser.add_argument("--server", default="blender-mcp", help="MCP stdio executable or wrapper on this machine")
    parser.add_argument("--output", type=Path, default=ROOT / "output")
    parser.add_argument("--skip-renders", action="store_true", help="Skip optional Cycles stills; preview-wave still renders")
    asyncio.run(run(parser.parse_args()))
