#!/usr/bin/env python2
import os
import sys
from imp import load_source

IDF_PATH = os.environ.get('IDF_PATH')
idf_tools = load_source("idf_tools", IDF_PATH + "/tools/idf_tools.py")
idf_tools.global_idf_path = IDF_PATH
idf_tools.global_tools_json = os.path.join(idf_tools.global_idf_path, idf_tools.TOOLS_FILE)

tools_info = idf_tools.load_tools_info()
tools_spec = [k for k, v in tools_info.items() if v.get_install_type() == idf_tools.IDFTool.INSTALL_ALWAYS]

for tool_spec in tools_spec:
    if '@' not in tool_spec:
        tool_name = tool_spec
        tool_version = None
    else:
        tool_name, tool_version = tool_spec.split('@', 1)
    if tool_name not in tools_info:
        sys.stderr.write('unknown tool name: {}\n'.format(tool_name))
        raise SystemExit(1)
    tool_obj = tools_info[tool_name]
    if not tool_obj.compatible_with_platform():
        sys.stderr.write('tool {} does not have versions compatible with platform {}\n'.format(tool_name, idf_tools.CURRENT_PLATFORM))
        raise SystemExit(1)
    if tool_version is not None and tool_version not in tool_obj.versions:
        sys.stderr.write('unknown version for tool {}: {}\n'.format(tool_name, tool_version))
        raise SystemExit(1)
    if tool_version is None:
        tool_version = tool_obj.get_recommended_version()
    assert tool_version is not None

    # idf_tools.apply_mirror_prefix_map(args, tool_obj.versions[tool_version].get_download_for_platform(idf_tools.PYTHON_PLATFORM))

    download_obj = tool_obj.versions[tool_version].get_download_for_platform(tool_obj._platform)
    if not download_obj:
        sys.stderr.write('No packages for tool {} platform {}!\n'.format(tool_obj.name, tool_obj._platform))
        raise idf_tools.DownloadError()

    url = download_obj.url
    print(url)
