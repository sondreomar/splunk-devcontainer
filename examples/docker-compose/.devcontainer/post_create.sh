#!/bin/zsh

# add bash aliases to .bash_aliases
cat .devcontainer/aliases.zsh >> ~/.oh-my-zsh/custom/aliases.zsh

# extract flow-map-viz app to sh1s apps
tar -xzf /workspace/flow-map-viz_1515.tgz -C /opt/splunk/etc/apps
