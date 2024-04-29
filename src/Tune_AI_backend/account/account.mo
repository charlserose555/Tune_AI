import Cycles               "mo:base/ExperimentalCycles";
import Principal            "mo:base/Principal";
import Error                "mo:base/Error";
import Nat                  "mo:base/Nat";
import Debug                "mo:base/Debug";
import Text                 "mo:base/Text";
import T                    "../types";
import Hash                 "mo:base/Hash";
import Nat32                "mo:base/Nat32";
import Nat64                "mo:base/Nat64";
import Iter                 "mo:base/Iter";
import Float                "mo:base/Float";
import Time                 "mo:base/Time";
import Int                  "mo:base/Int";
import Result               "mo:base/Result";
import Blob                 "mo:base/Blob";
import Array                "mo:base/Array";
import Buffer               "mo:base/Buffer";
import Trie                 "mo:base/Trie";
import TrieMap              "mo:base/TrieMap";
import CanisterUtils        "../utils/canister.utils";
import Prim                 "mo:⛔";
import Map                  "mo:stable-hash-map/Map";
import B                    "mo:stable-buffer/StableBuffer";
import Utils                "../utils/utils";
import WalletUtils          "../utils/wallet.utils";
import IC                   "../ic.types";
import Env                  "../env";

 shared({caller = managerCanister}) actor class ArtistBucket(accountInfo: ?T.PrincipalInfo, artistPrincipal: Principal, cyclesManager: Principal) = this {

  let { ihash; nhash; thash; phash; calcHash } = Map;

  type ArtistAccountData         = T.ArtistAccountData;
  type UserId                    = T.UserId;
  type ContentInit               = T.ContentInit;
  type ContentId                 = T.ContentId;
  type ContentData               = T.ContentData;
  type ChunkId                   = T.ChunkId;
  type CanisterId                = T.CanisterId;
  type StatusRequest             = T.StatusRequest;
  type StatusResponse            = T.StatusResponse;
  type ManagerId                 = Principal;
  type CanisterStatus            = IC.canister_status_response;
  
  stable var MAX_CANISTER_SIZE: Nat =     68_700_000_000; // <-- approx. 64GB
  stable var CYCLE_AMOUNT : Nat     =    100_000_000_000; 
  let maxCycleAmount                = 80_000_000_000_000;
  let top_up_amount                 =  2_000_000_000_000;


  private let ic : IC.Self        = actor "aaaaa-aa";
  var VERSION: Nat         = 1;
  stable var initialised: Bool    = false;
  stable var owner: Principal     = artistPrincipal;
  // Stable variable holding the cycles requester

  private let walletUtils : WalletUtils.WalletUtils = WalletUtils.WalletUtils();
  private let canisterUtils : CanisterUtils.CanisterUtils = CanisterUtils.CanisterUtils();

  stable let artistData = Map.new<UserId, ArtistAccountData>(phash);

// #region - CREATE CONTENT CANISTERS
  public func createProfileInfo(accountInfo: ?ArtistAccountData) : async (Bool) { // Initialise new cansiter. This is called only once after the account has been created. I
    switch(accountInfo){
      case(?info){
        let a = Map.put(artistData, phash, artistPrincipal, info);
        return true;
      };case null return false;
    };
  };

  public shared({caller}) func editProfileInfo( info: ArtistAccountData) : async (Bool){
    assert(caller == owner or Utils.isManager(caller));
    var exist = Map.get(artistData, phash, caller);

    if (exist != null){
        var update = Map.replace(artistData, phash, caller, info);
        return true;
    } else {
      var update = Map.add(artistData, phash, caller, info);  
      return true;
    }; 
  };

  public query({caller}) func getProfileInfo(user: UserId) : async (?ArtistAccountData){
    // assert(caller == owner or Utils.isManager(caller));
    Map.get(artistData, phash, user);
  };
// #endregion

// #region - UTILS
  

  public func getCurrentCyclesBalance(): async Nat {
    Cycles.balance();
  };


  public shared({caller}) func checkCyclesBalance () : async(){
    Debug.print("@checkCyclesBalance: caller of this function is: " # debug_show caller);
    // assert(caller == owner or Utils.isManager(caller) or caller == Principal.fromActor(this));
    Debug.print("@checkCyclesBalance: creator of this smart contract: " # debug_show managerCanister);
    let bal = getCurrentCycles();
    Debug.print("@checkCyclesBalance: Cycles Balance After Canister Creation: " # debug_show bal);
    if(bal < CYCLE_AMOUNT + top_up_amount){
       await transferCyclesToThisCanister();
    };
  };

  public func transferCyclesToThisCanister() : async (){
    let self: Principal = Principal.fromActor(this);
    let can = actor(Principal.toText(managerCanister)): actor { 
      transferCyclesToAccountCanister: (Principal, Nat) -> async ();
    };
    await can.transferCyclesToAccountCanister(self, top_up_amount);
  };

  public shared({caller}) func changeCycleAmount(amount: Nat) : (){
    if (not Utils.isManager(caller)) {
      throw Error.reject("@changeCycleAmount: Unauthorized access. Caller is not the manager. " # Principal.toText(caller));
    };
    CYCLE_AMOUNT := amount;
  };

  public shared({caller}) func changeCanisterSize(newSize: Nat) : (){
    if (not Utils.isManager(caller)) {
      throw Error.reject("@changeCanisterSize: Unauthorized access. Caller is not the manager. " # Principal.toText(caller));
    };
    MAX_CANISTER_SIZE := newSize;
  };

  private func getCurrentHeapMemory(): Nat {
    Prim.rts_heap_size();
  };

  private func getCurrentMemory(): Nat {
    Prim.rts_memory_size();
  };



  private func getCurrentCycles(): Nat {
    Cycles.balance();
  };



  public query({caller}) func getStatus(request: ?StatusRequest): async ?StatusResponse {
    // assert(caller == owner or caller == managerCanister or Utils.isManager(caller));
    Debug.print("caller principal: " # debug_show caller);
    Debug.print("manager principal: " # debug_show Env.manager);
    
    // assert(Utils.isManager(caller));
    switch(request) {
      case (?_request) {
          var cycles: ?Nat = null;
          if (_request.cycles) {
              cycles := ?getCurrentCycles();
          };
          var memory_size: ?Nat = null;
          if (_request.memory_size) {
              memory_size := ?getCurrentMemory();
          };
          var heap_memory_size: ?Nat = null;
          if (_request.heap_memory_size) {
              heap_memory_size := ?getCurrentHeapMemory();
          };
          var version: ?Nat = null;
          if (_request.version) {
              version := ?getVersion();
          };
          return ?{
              cycles = cycles;
              memory_size = memory_size;
              heap_memory_size = heap_memory_size;
              version = version;
          };
      };
      case null return null;
    };
  };


   private func wallet_receive() : async { accepted: Nat64 } {

    let available = Cycles.available();
    let accepted = Cycles.accept(Nat.min(available, top_up_amount));
    Debug.print("@available" # debug_show available);
    Debug.print("@accepted" # debug_show accepted);

    // let accepted = Cycles.accept(top_up_amount);
    { accepted = Nat64.fromNat(accepted) };
  };


  public query({caller}) func getPrincipalThis() :  async (Principal){
    if (not Utils.isManager(caller)) {
      throw Error.reject("@getPrincipalThis: Unauthorized access. Caller is not a manager.");
    };
    Principal.fromActor(this);
  };

  public shared({caller}) func deleteAccount(user: Principal): async(){
    // assert(caller == owner or Utils.isManager(caller));
    let canisterId :?Principal = ?(Principal.fromActor(this));
    let res = await canisterUtils.deleteCanister(canisterId);
  };

  public shared ({caller}) func transferFreezingThresholdCycles() : async () {
    assert(Utils.isManager(caller) or caller == owner or caller == managerCanister);
    await walletUtils.transferFreezingThresholdCycles(managerCanister);
  };


  private func getVersion() : Nat {
		return VERSION;
	};  

   public shared({caller}) func getCanisterStatus() : async CanisterStatus {
    // if (not Utils.isManager(caller)) {
    //   throw Error.reject("@cyclesBalance: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
    // };
    return await canisterUtils.canisterStatus(?Principal.fromActor(this));
  };

};


// public shared func wallet_send(wallet_send: shared () -> async { accepted: Nat }, amount : Nat) : async { accepted: Nat } {// Signature of the wallet recieve function in the calling canister
//     Cycles.add(amount);
//     let l = await wallet_send();
//     { accepted = amount };
//   };