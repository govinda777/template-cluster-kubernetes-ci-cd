package main

# Deny use of legacy Ingress resources
deny[msg] contains msg if {
  input.kind == "Ingress"
  msg := sprintf("Ingress resource '%s' is prohibited. Use Kubernetes Gateway API (HTTPRoute) instead.", [input.metadata.name])
}

# Enforce that HTTPRoute must reference a parent Gateway
deny[msg] contains msg if {
  input.kind == "HTTPRoute"
  not has_parent_refs(input)
  msg := sprintf("HTTPRoute '%s' must define 'spec.parentRefs' to link with a Gateway.", [input.metadata.name])
}

deny[msg] contains msg if {
  input.kind == "HTTPRoute"
  has_parent_refs(input)
  not has_valid_parent_name(input)
  msg := sprintf("HTTPRoute '%s' parentRef must define a valid non-empty 'name'.", [input.metadata.name])
}

# Helper rules
has_parent_refs(resource) if {
  resource.spec.parentRefs
  count(resource.spec.parentRefs) > 0
}

has_valid_parent_name(resource) if {
  parent := resource.spec.parentRefs[_]
  parent.name
  parent.name != ""
}
