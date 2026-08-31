spark_locals_without_parens = [
  allow_nil?: 1,
  attribute_type: 1,
  event_log: 1,
  ignore_actions: 1,
  logger_metadata_keys: 1,
  only_actions: 1,
  persist_actor_primary_key: 2,
  persist_actor_primary_key: 3,
  primary_key_type: 1,
  public_fields: 1,
  record_id_type: 1
]

# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
