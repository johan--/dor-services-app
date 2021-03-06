# frozen_string_literal: true

Dor.configure do
  # rubocop:disable Style/MultilineIfModifier
  ssl do
    cert_file Settings.ssl.cert_file
    key_file Settings.ssl.key_file
    key_pass Settings.ssl.key_pass
  end if Settings.ssl
  # rubocop:enable Style/MultilineIfModifier

  fedora do
    url Settings.fedora_url
  end

  solr do
    url Settings.solr.url
  end

  suri do
    mint_ids     Settings.suri.mint_ids
    id_namespace Settings.suri.id_namespace
    url          Settings.suri.url
    user         Settings.suri.user
    pass         Settings.suri.pass
  end

  stacks do
    local_workspace_root        Settings.stacks.local_workspace_root
    local_stacks_root           Settings.stacks.local_stacks_root
  end
end
