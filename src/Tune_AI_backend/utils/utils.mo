import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";

import Env "../env";

module {
  public func isPrincipalEqual(x : Principal, y : Principal) : Bool {x == y};

  public func isPrincipalNotEqual(x : Principal, y : Principal) : Bool {x != y};

  public func isAdmin(caller : Principal) : Bool {
    hasPrivilege(caller, Env.admin);
  };

  public func isManager(caller : Principal) : Bool {
    hasPrivilege(caller, Env.manager);
  };

  public func beBytes(n : Nat32) : [Nat8] {
    func byte(n : Nat32) : Nat8 {
      Nat8.fromNat(Nat32.toNat(n & 0xff))
    };
    [byte(n >> 24), byte(n >> 16), byte(n >> 8), byte(n)]
  };

  private func hasPrivilege(caller : Principal, privileges : [Text]) : Bool { // rename function header from admin 
    func toPrincipal(entry : Text) : Principal {
      Principal.fromText(entry);
    };

    let principals : [Principal] = Array.map(privileges, toPrincipal);

    func filter(admin : Principal) : Bool {
      admin == caller;
    };

    let admin : ?Principal = Array.find(principals, filter);

    switch (admin) {
      case (null) {
        return false;
      };
      case (?admin) {
        return true;
      };
    };
  };
};