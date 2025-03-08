{ lib, ... }:

# This file exports several helper functions for introspecting
# NixOS module options, handling submodules, removing _module, etc.

let
  describeType =
    t:
    let
      name = t.name or "???";
      child =
        if (t.functor ? wrapped) && t.functor.wrapped != null
        then t.functor.wrapped
        else null;
    in
    # We'll pattern-match on known wrappers.
    if name == "nullOr" && child != null then
      "nullOr " + "(" + describeType child + ")"

    else if name == "listOf" && child != null then
      "listOf " + "(" + describeType child + ")"

    else if name == "attrsOf" && child != null then
      "attrsOf " + "(" + describeType child + ")"

    else
    # For anything else just return the name
      name;

  # Unwrap 'nullOr' -> child type
  unwrapNullOr =
    t:
    if t.name == "nullOr" && (t.functor ? wrapped)
    then t.functor.wrapped
    else t;

  # Obtains submodule options from an 'attrsOf (submodule)'
  getSubOpts =
    type:
    let
      raw = (type.functor.wrapped.getSubOptions or (_: { })) { };

      # If 'raw' is still a function, we cannot introspect it further
      cleaned = if builtins.isFunction raw then { } else lib.removeAttrs raw [ "_module" ];
    in
    if cleaned == { } then null else parseOpts cleaned;

  # Checks if the type is 'attrsOf (submodule)' or 'listOf (attrsOf (submodule))'
  resolveSubmodule =
    t:
    let
      unwrapped = unwrapNullOr t;
    in
    if unwrapped.name == "attrsOf"
      && (unwrapped.functor ? wrapped)
      && unwrapped.functor.wrapped.name == "submodule"
    then
    # Direct 'attrsOf (submodule)'
      getSubOpts unwrapped

    else if unwrapped.name == "listOf" && (unwrapped.functor ? wrapped) then
      let
        # Possibly nullOr or direct
        child = unwrapNullOr unwrapped.functor.wrapped;
      in
      if child.name == "attrsOf"
        && (child.functor ? wrapped)
        && child.functor.wrapped.name == "submodule"
      then
      # 'listOf (attrsOf submodule)'
        getSubOpts child
      else
        null

    else
      null;

  # Recursively processes each option, unwrapping nullOr and submodules.
  parseOpts =
    options:
    lib.attrsets.mapAttrsRecursiveCond (v: ! lib.options.isOption v)
      (_k: v:
      let
        typeString = describeType v.type;
        subOpts = resolveSubmodule v.type;

        baseAttrs = {
          type = typeString;
          default = v.default or null;
          description = v.description or null;
          example = v.example or null;
        };
      in
      if subOpts != null && subOpts != { }
      then baseAttrs // { options = subOpts; }
      else baseAttrs
      )
      options;
in
{
  inherit parseOpts getSubOpts resolveSubmodule unwrapNullOr;
}
