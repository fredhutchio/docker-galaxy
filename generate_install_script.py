#!/usr/bin/env python

import xml.etree.ElementTree as ET
import argparse

#####

parser = argparse.ArgumentParser(description="""
Generate a tool install script from a shed_tool_conf.xml file.
""")
parser.add_argument('--latest', action='store_true',
                    help='install latest revisions instead of those specified')
parser.add_argument('tool_conf', help='tool config file')
args = parser.parse_args()

#####

main_sections = { "Get Data": 'getext',
                  "Send Data": 'send',
                  "Lift-Over": 'liftOver',
                  "Text Manipulation": 'textutil',
                  "Filter and Sort": 'filter',
                  "Join, Subtract and Group": 'group',
                  "Convert Formats": 'convert',
                  "Extract Features": 'features',
                  "Fetch Sequences": 'fetchSeq',
                  "Fetch Alignments": 'fetchAlign',
                  "Statistics": 'stats',
                  "Graph/Display Data": 'plots' }

cmd_tmpl = ("python ./scripts/api/install_tool_shed_repositories.py "
            "--local $GALAXY_INSTALL_URL --api $GALAXY_INSTALL_KEY "
            "--tool-deps --repository-deps ")

repo_tmpl = "--url https://{} --owner {} --name {} "
repos_seen = set()

#####

tree = ET.parse(args.tool_conf)
root = tree.getroot()

print "#!/bin/sh\nset -eux\n"

for section in root.iter('section'):
    section_exists = False
    section_name = section.get('name')

    if section_name in main_sections:
        section_exists = True
        section_id = main_sections[section_name]
    else:
        # Use Galaxy's method of assigning section IDs from
        # galaxy/lib/tool_shed/galaxy_install/tools/tool_panel_manager.py
        section_id = str(section_name.lower().replace(' ', '_'))

    for tool in section.iter('tool'):
        if tool.find('tool_shed') is None:
            continue

        tool_shed = tool.find('tool_shed').text
        owner = tool.find('repository_owner').text
        name = tool.find('repository_name').text
        revision = tool.find('installed_changeset_revision').text

        repo_str = repo_tmpl.format(tool_shed, owner, name)
        if not args.latest:
            repo_str += "--revision {} ".format(revision)

        # It's legal for a tool to be in multiple sections, so append
        # the section ID to the repository string for the purpose of
        # detecting duplicates.
        repo_key = repo_str + section_id
        if repo_key in repos_seen:
            continue
        else:
            repos_seen.add(repo_key)

        # The first tool in each section will be passed to the install
        # script with the --panel-section-name argument to create the
        # section. Remaining tools in the section will be passed with
        # the --panel-section-id argument.

        if section_exists:
            repo_str += "--panel-section-id {}".format(section_id)
        else:
            repo_str += "--panel-section-name \"{}\"".format(section_name)
            section_exists = True

        print cmd_tmpl + repo_str
