%=============================================================================
% Generate
%=============================================================================

%-----------------------------------------------------------------------------
% Version semantics
%-----------------------------------------------------------------------------

% If something is a package, it has only one version and that must be a
% possible version.
1 { version(P, V) : version_possible(P, V) } 1 :- node(P).

% If a version is declared but conflicted, it's not possible.
version_possible(P, V) :- version_declared(P, V), not version_conflict(P, V).
#defined version_conflict/2.

%-----------------------------------------------------------------------------
% Dependency semantics
%-----------------------------------------------------------------------------
% declared dependencies are real if they're not virtual
depends_on(P, D) :- declared_dependency(P, D), not virtual(D), node(P).

% if you declare a dependency on a virtual, you depend on one of its providers
1 { depends_on(P, Q) : provides_virtual(Q, V) } 1
    :- declared_dependency(P, V), virtual(V), node(P).

needed(D) :- depends_on(_, D), node(D).
needed(P) :- root(P).
:- node(P), not needed(P).
#defined root/1.

% real dependencies imply new nodes.
node(D) :- node(P), depends_on(P, D).

% do not warn if generated program contains none of these.
#defined depends_on/2.
#defined declared_dependency/2.
#defined virtual/1.
#defined provides_virtual/2.

%-----------------------------------------------------------------------------
% Variant semantics
%-----------------------------------------------------------------------------
% one variant value for single-valued variants.
1 { variant_value(P, V, X) : variant_possible_value(P, V, X) } 1
    :- node(P), variant(P, V), variant_single_value(P, V).

% if a variant is set to anything, it is considered 'set'.
variant_set(P, V) :- variant_set(P, V, _).

% variant_set is an explicitly set variant value. If it's not 'set',
% we revert to the default value. If it is set, we force the set value
variant_value(P, V, X) :- node(P), variant(P, V), variant_set(P, V, X).

% prefer default values.
variant_not_default(P, V, X, 1)
    :- variant_value(P, V, X),
       not variant_default_value(P, V, X),
       node(P).

variant_not_default(P, V, X, 0)
    :- variant_value(P, V, X),
       variant_default_value(P, V, X),
       node(P).

#minimize { N@1,P,V,X : variant_not_default(P, V, X, N) }.

% suppress wranings about this atom being unset.  It's only set if some
% spec or some package sets it, and without this, clingo will give
% warnings like 'info: atom does not occur in any rule head'.
#defined variant_set/3.
#defined variant_single_value/2.

%-----------------------------------------------------------------------------
% Architecture semantics
%-----------------------------------------------------------------------------

% one platform, os, target per node.
1 { arch_platform(P, A) : arch_platform(P, A) } 1 :- node(P).
1 { arch_os(P, A) : arch_os(P, A) } 1             :- node(P).
1 { arch_target(P, T) : arch_target(P, T) } 1     :- node(P).

% arch fields for pkg P are set if set to anything
arch_platform_set(P) :- arch_platform_set(P, _).
arch_os_set(P) :- arch_os_set(P, _).
arch_target_set(P) :- arch_target_set(P, _).

% avoid info warnings (see variants)
#defined arch_platform_set/2.
#defined arch_os_set/2.
#defined arch_target_set/2.

% if architecture value is set, it's the value
arch_platform(P, A) :- node(P), arch_platform_set(P, A).
arch_os(P, A) :- node(P), arch_os_set(P, A).
arch_target(P, A) :- node(P), arch_target_set(P, A).

% if no architecture is set, fall back to the default architecture value.
arch_platform(P, A) :- node(P), not arch_platform_set(P),
                       arch_platform_default(A).
arch_os(P, A)       :- node(P), not arch_os_set(P), arch_os_default(A).
arch_target(P, A)   :- node(P), not arch_target_set(P), arch_target_default(A).

% propagate platform, os, target downwards
% TODO: handle multiple dependents and arch compatibility
arch_platform_set(D, A) :- node(D), depends_on(P, D), arch_platform_set(P, A).
arch_os_set(D, A) :- node(D), depends_on(P, D), arch_os_set(P, A).
arch_target_set(D, A) :- node(D), depends_on(P, D), arch_target_set(P, A).

%-----------------------------------------------------------------------------
% Compiler semantics
%-----------------------------------------------------------------------------

% one compiler per node
{ node_compiler(P, C) : node_compiler(P, C) } = 1 :- node(P).
{ node_compiler_version(P, C, V) :
  node_compiler_version(P, C, V) } = 1            :- node(P).

% compiler fields are set if set to anything
node_compiler_set(P) :- node_compiler_set(P, _).
node_compiler_version_set(P, C) :- node_compiler_version_set(P, C, _).

% avoid warnings: these are set by generated code and it's ok if they're not
#defined node_compiler_set/2.
#defined node_compiler_version_set/3.

% if compiler value of node is set to anything, it's the value.
node_compiler(P, C)
  :- node(P), compiler(C), node_compiler_set(P, C).
node_compiler_version(P, C, V)
  :- node(P), compiler(C), compiler_version(C, V), node_compiler(P, C),
     node_compiler_version_set(P, C, V).

% node compiler versions can only be from the available compiler versions
:- node(P), compiler(C), node_compiler(P, C), node_compiler_version(P, C, V),
   not compiler_version(C, V).

% if no compiler is set, fall back to default.
node_compiler(P, C)
  :- node(P), compiler(C), not node_compiler_set(P),
     node_compiler_default(P, C).
node_compiler_version(P, C, V)
  :- node(P), compiler(C), compiler_version(C, V),
     not node_compiler_version_set(P, C, V),
     node_compiler_default_version(P, C, V).

% propagate compiler, compiler version to dependencies
node_compiler_set(D, C)
  :- node(D), compiler(C), depends_on(P, D), node_compiler_set(P, C).
node_compiler_version_set(D, C, V)
  :- node(D), compiler(C), depends_on(P, D), node_compiler(D, C),
     node_compiler_version_set(P, C, V).