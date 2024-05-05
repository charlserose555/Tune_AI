import Cycles             "mo:base/ExperimentalCycles";
import Principal          "mo:base/Principal";
import Error              "mo:base/Error";
import IC                 "../ic.types";
import ArtistBucket       "../account/account";
import Nat                "mo:base/Nat";
import Map                "mo:stable-hash-map/Map";
import Debug              "mo:base/Debug";
import Text               "mo:base/Text";
import T                  "../types";
import Hash               "mo:base/Hash";
import Nat32              "mo:base/Nat32";
import Nat64              "mo:base/Nat64";
import Iter               "mo:base/Iter";
import Float              "mo:base/Float";
import Time               "mo:base/Time";
import Int                "mo:base/Int";
import Result             "mo:base/Result";
import Blob               "mo:base/Blob";
import Array              "mo:base/Array";
import Buffer             "mo:base/Buffer";
import Trie               "mo:base/Trie";
import TrieMap            "mo:base/TrieMap";
import CanisterUtils      "../utils/canister.utils";
import WalletUtils        "../utils/wallet.utils";
import Utils              "../utils/utils";
import Prim               "mo:⛔";
import Env                "../env";
import B                  "mo:stable-buffer/StableBuffer";

actor Manager {

  type ArtistAccountData              = T.ArtistAccountData;
  type PrincipalInfo                  = T.PrincipalInfo;
  type UserType                       = T.UserType;
  type UserId                         = T.UserId;
  type CanisterId                     = T.CanisterId;
  type StatusRequest                  = T.StatusRequest;
  type StatusResponse                 = T.StatusResponse;
  type CanisterStatus                 = IC.canister_status_response;
  
  private let canisterUtils : CanisterUtils.CanisterUtils = CanisterUtils.CanisterUtils();
  private let walletUtils : WalletUtils.WalletUtils       = WalletUtils.WalletUtils();

  private let ic : IC.Self = actor "aaaaa-aa";

  private let cyclesManagerId : Principal = Principal.fromText("bnz7o-iuaaa-aaaaa-qaaaa-cai");

  let { ihash; nhash; thash; phash; calcHash } = Map;

  var CYCLE_AMOUNT : Nat         = 1_000_000_000_000;
  var TRANSFER_CYCLE_AMOUNT : Nat  = 100_000_000_000;
  stable var numOfFanAccounts: Nat      = 0;
  stable var MAX_CANISTER_SIZE: Nat     = 68_700_000_000; // <-- approx. 64GB
  stable var numOfArtistAccounts: Nat   = 0;
  var VERSION: Nat               = 1;
  let top_up_amount                     =  2_000_000_000_000;  

  stable let userToCanisterMap    = Map.new<Text, (Principal, Nat64)>(thash);
  stable let fanAccountsMap       = Map.new<UserId, CanisterId>(phash);
  stable let artistAccountData            = Map.new<UserId, ArtistAccountData>(phash);


  // public shared({caller}) func createAccountCanister(accountData: PrincipalInfo) : async (?Principal){
    // if (caller != accountData.userPrincipal) {
    //   throw Error.reject("@createProfileArtist: Unauthorized access. Caller is not the artist. Caller: " # Principal.toText(caller));
    // };
    // await createCanister(accountData.userPrincipal, #artist, ?accountData);
  // };  

  // private func createCanister(userID: Principal, userType: UserType, accountDataArtist: ?PrincipalInfo): async (?Principal) {
  //   Debug.print("@createCanister: userID: " # Principal.toText(userID));
    
  //   let self: Principal = Principal.fromActor(Manager);

  //   var canisterId: ?Principal = null;

  //   switch(Map.get(artistAccountsMap, phash, userID)){
  //     case(?exists){
  //       return Map.get(artistAccountsMap, phash, userID);
  //     }; case null {
  //       let bal = getCurrentCycles();
  //       Debug.print("@createCanister: Current Manage Canister cycles: " #debug_show bal);

  //       if(bal < CYCLE_AMOUNT + TRANSFER_CYCLE_AMOUNT){
  //         // notify frontend that cycles is below threshold
  //         throw Error.reject("@createCanister: Manager canister is out of cycles! Please replenish supply." # Nat.toText((CYCLE_AMOUNT + TRANSFER_CYCLE_AMOUNT)));
  //       };

  //       Cycles.add(CYCLE_AMOUNT);
  //       let b = await ArtistBucket.ArtistBucket(accountDataArtist, userID, cyclesManagerId);
  //       canisterId := ?(Principal.fromActor(b));
  //     };
  //   };

  //   switch (canisterId) {
  //     case null {
  //       throw Error.reject("@createCanister: Bucket init error, your account canister could not be created.");
  //     };
  //     case (?canisterId) {
  //       let self: Principal = Principal.fromActor(Manager);

  //       let controllers: ?[Principal] = ?[canisterId, userID, self, cyclesManagerId, Principal.fromText(Env.manager[0])];
        
  //       await ic.update_settings(({canister_id = canisterId; 
  //         settings = {
  //           controllers = controllers;
  //           freezing_threshold = null;
  //           memory_allocation = null;
  //           compute_allocation = null;
  //         }}));

  //       await walletUtils.transferCycles(canisterId, TRANSFER_CYCLE_AMOUNT);

  //       let b = Map.put(artistAccountsMap, phash, userID, canisterId);
  //       numOfArtistAccounts := numOfArtistAccounts + 1;

  //       return ?canisterId;
  //     };
  //   };
  // };

  public shared({caller}) func editProfileInfo( info: ArtistAccountData) : async (Bool){
    assert(caller == info.userPrincipal or Utils.isManager(caller));
    var exist = Map.get(artistAccountData, phash, caller);

    if (exist != null){
        var update = Map.replace(artistAccountData, phash, caller, info);
        return true;
    } else {
      var update = Map.add(artistAccountData, phash, caller, info);  
      return true;
    }; 
  };

  public query({caller}) func getProfileInfo(user: UserId) : async (?ArtistAccountData){
    // assert(caller == owner or Utils.isManager(caller));
    Map.get(artistAccountData, phash, user);
  };

  private func wallet_receive() : async { accepted: Nat64 } {
    let available = Cycles.available();
    let accepted = Cycles.accept(Nat.min(available, top_up_amount));
    // let accepted = Cycles.accept(top_up_amount);
    { accepted = Nat64.fromNat(accepted) };
  };

// #endregion



  public query func getTotalAccounts() :  async Nat{   
    numOfArtistAccounts   
  }; 


  public query({caller}) func getArtistList() : async [(UserId, ArtistAccountData)]{   
    // if (not Utils.isManager(caller)) {
    //   throw Error.reject("@getArtistAccountEntries: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
    // };
    var res = Buffer.Buffer<(UserId, ArtistAccountData)>(2);
    for((key, value) in Map.entries(artistAccountData)){
      var artistId : Principal = key;
      var canisterId : ArtistAccountData = value;
      res.add(artistId, canisterId);
    };       
    return Buffer.toArray(res);

    // Iter.toArray(Map.entries(artistAccountsMap));    
  };



  // public query({caller}) func getCanisterbyIdentity(artist: Principal) : async (?Principal){   
  //   // assert(caller == artist or Utils.isManager(caller));
  //   Map.get(artistAccountsMap, phash, artist);    
  // };


  // public query({caller}) func getOwnershipOfCanister(canisterId: Principal) : async (?UserId){ 
  //   if (not Utils.isManager(caller)) {
  //     throw Error.reject("@getOwnerOfArtistCanister: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
  //   };
  //   for((key, value) in Map.entries(artistAccountsMap)){
  //     var artist: ?UserId = ?key;
  //     var canID = value;
  //     if (canID == canisterId){
  //       return artist;
  //     };
  //   };
  //   return null;
  // };

  public shared({caller}) func getCanisterWtihAvailableMemory(canisterId: Principal) : async ?Nat{
    if (not Utils.isManager(caller)) {
      throw Error.reject("@getAvailableMemoryCanister: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
    };

    let can = actor(Principal.toText(canisterId)): actor { 
        getStatus: (?StatusRequest) -> async ?StatusResponse;
    };

    let request : StatusRequest = {
        cycles: Bool = false;
        heap_memory_size: Bool = false; 
        memory_size: Bool = true;
        version: Bool = false;
    };
    
    switch(await can.getStatus(?request)){
      case(?status){
        switch(status.memory_size){
          case(?memSize){
            let availableMemory: Nat = MAX_CANISTER_SIZE - memSize;
            return ?availableMemory;
          };
          case null null;
        };
      };
      case null null;
    };
  };


  // public query({caller}) func getStatus(request: ?StatusRequest): async ?StatusResponse {
  //   Debug.print("@getStatus: caller: " # Principal.toText(caller));
  //   // assert(Utils.isManager(caller));
  //   Debug.print("caller principal: " # debug_show caller);
  //   Debug.print("manager principal: " # debug_show Env.manager);
  //     switch(request) {
  //         case (null) {
  //             return null;
  //         };
  //         case (?_request) {
  //             var cycles: ?Nat = null;
  //             if (_request.cycles) {
  //                 cycles := ?getCurrentCycles();
  //             };
  //             var memory_size: ?Nat = null;
  //             if (_request.memory_size) {
  //                 memory_size := ?getCurrentMemory();
  //             };
  //             var heap_memory_size: ?Nat = null;
  //             if (_request.heap_memory_size) {
  //                 heap_memory_size := ?getCurrentHeapMemory();
  //             };
  //             var version: ?Nat = null;
  //             if (_request.version) {
  //                 version := ?getVersion();
  //             };
  //             return ?{
  //                 cycles = cycles;
  //                 memory_size = memory_size;
  //                 heap_memory_size = heap_memory_size;
  //                 version = version;
  //             };
  //         };
  //     };
  // };




  private func getCurrentHeapMemory(): Nat {
    Prim.rts_heap_size();
  };




  private func getCurrentMemory(): Nat {
    Prim.rts_memory_size();
  };




  private func getCurrentCycles(): Nat {
    Cycles.balance();
  };


  public query func cyclesBalance() : async (Nat) {
    // if (not Utils.isManager(caller)) {
    //   throw Error.reject("@cyclesBalance: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
    // };
    return walletUtils.cyclesBalance();
  };


// #region - UTILS
  public shared({caller}) func updateCycleAmount(amount: Nat) : (){  // utils based 
    if (not Utils.isManager(caller)) {
      throw Error.reject("@changeCycleAmount: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
    };
    CYCLE_AMOUNT := amount;   
  };

  public shared({caller}) func updateCanisterSize(newSize: Nat) : (){    // utils based
    if (not Utils.isManager(caller)) {
      throw Error.reject("@changeCanisterSize: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
    };
    MAX_CANISTER_SIZE := newSize;
  };

  // public shared({caller}) func transferOwnershipAccountCanister(currentOwner: Principal, newOwner: Principal) : async (){
  //   assert(caller == currentOwner or Utils.isManager(caller));
  //   switch(Map.get(artistAccountsMap, phash, currentOwner)){
  //     case(?canisterId){
  //       let update = Map.replace(artistAccountsMap, phash, newOwner, canisterId);
  //     }; case null throw Error.reject("@transferOwnershipArtist: This artist account doesnt exist.");
  //   };
  // };

  // public shared({caller}) func transferCyclesToAccountCanister(canisterId : Principal, amount : Nat) : async () { 
  //   // assert(caller == canisterId or Utils.isManager(caller));
  //   for(value in Map.vals(artistAccountsMap)){
  //     if(canisterId == value){
  //       await walletUtils.transferCycles(canisterId, amount);
  //     }
  //   };
  // };

  public  func transferCyclesToCanister(canisterId : Principal, amount : Nat) : async () { 
    // assert(caller == canisterId or Utils.isManager(caller));
    
        await walletUtils.transferCycles(canisterId, amount);      
  };



  // public shared({caller}) func transferCyclesToContentCanister(accountCanisterId : Principal, contentCanisterId : Principal, amount : Nat) : async () { 
  //   // assert(caller == contentCanisterId or Utils.isManager(caller) or caller == accountCanisterId);
  //   for(value in Map.vals(artistAccountsMap)){
  //     if(accountCanisterId == value){
  //       let can = actor(Principal.toText(accountCanisterId)): actor { 
  //         getAllContentCanisters: () -> async [CanisterId];
  //       };
  //       for(canID in Iter.fromArray(await can.getAllContentCanisters())){
  //         if(canID == contentCanisterId){
  //           await walletUtils.transferCycles(contentCanisterId, amount);
  //         }
  //       };
  //     }
  //   };
  // };


  // public shared({caller}) func deleteAccountCanister(user: UserId, canisterId: Principal) :  async (Bool){
  //   // if (not Utils.isManager(caller)) {
  //   //   throw Error.reject("@deleteAccountCanister: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
  //   // };
  //   switch(Map.get(artistAccountsMap, phash, user)){
  //     case(?artistAccount){
  //       Map.delete(artistAccountsMap, phash, user);
  //       let res = await canisterUtils.deleteCanister(?canisterId);
  //       return true;
  //     };
  //     case null false
  //   }
  // };

  public shared({caller}) func installCode(canisterId : Principal, owner : Blob, wasmModule : Blob) : async () {
    Debug.print("@installCode: caller is: " # Principal.toText(caller));
    if (not Utils.isManager(caller)) {
      throw Error.reject("@installCode: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
    };
    Debug.print("install code has been initiated");
    await canisterUtils.installCode(canisterId, owner, wasmModule);
  };


   public shared({caller}) func getCanisterStatus() : async CanisterStatus {
    // if (not Utils.isManager(caller)) {
    //   throw Error.reject("@cyclesBalance: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
    // };
    return await canisterUtils.canisterStatus(?Principal.fromActor(Manager));
  };


  // #endregion
};