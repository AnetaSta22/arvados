# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: AGPL-3.0

{%- set curr_tpldir = tpldir %}
{%- set tpldir = 'arvados' %}
{%- from "arvados/map.jinja" import arvados with context %}
{%- set tpldir = curr_tpldir %}

arvados_test_salt_states_examples_single_host_etc_hosts_host_present:
  host.present:
    - ip: 127.0.0.2
    - names:
      - {{ arvados.cluster.name }}.{{ arvados.cluster.domain }}
      # FIXME! This just works for our testings.
      # Won't work if the cluster name != host name
      {%- for entry in [
          'api',
          'collections',
          'controller',
          'download',
          'keep',
          'keepweb',
          'keep0',
          'shell',
          'workbench',
          'workbench2',
          'ws',
        ]
      %}
      - {{ entry }}
      {%- endfor %}
