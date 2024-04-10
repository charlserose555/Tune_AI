let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.10.4-20240112/package-set.dhall sha256:7b24c36d46a2da005875922cb4425207ae4fae9214eb710f38a70ed69ce8146f
let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  -- This is where you can add your own packages to the package-set
  additions =
    [] : List Package



let additions=[
  {name = "stable-hash-map",
  repo = "https://github.com/ZhenyaUsenko/motoko-hash-map",
  version="v8.0.0", dependencies = ["base"]},
  {name = "stable-buffer",
  repo = "https://github.com/canscale/StableBuffer",
  version="v1.2.0", dependencies = ["base"]}
]


let
  {- This is where you can override existing packages in the package-set

     For example, if you wanted to use version `v2.0.0` of the foo library:
     let overrides = [
         { name = "foo"
         , version = "v2.0.0"
         , repo = "https://github.com/bar/foo"
         , dependencies = [] : List Text
         }
     ]
  -}
  overrides =
    [] : List Package

in  upstream # additions # overrides
