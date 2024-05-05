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
import ArtistContentBucket  "../content/content";

actor ContentManager {
    type ContentInit               = T.ContentInit;
    type ContentId                 = T.ContentId;
    type ContentData               = T.ContentData;
    type ChunkId                   = T.ChunkId;
    type CanisterId                = T.CanisterId;
    type StatusRequest             = T.StatusRequest;
    type StatusResponse            = T.StatusResponse;
    type ManagerId                 = Principal;
    type CanisterStatus            = IC.canister_status_response;
    type UserId                    = T.UserId;

    let { ihash; nhash; thash; phash; calcHash } = Map;
    stable var MAX_CANISTER_SIZE: Nat =     68_700_000_000; // <-- approx. 64GB
    stable var CYCLE_AMOUNT : Nat     =    100_000_000_000; 
    stable let content = Map.new<ContentId, ContentData>(thash);
    stable let contentIds = B.init<ContentId>();
    stable let contentCanisterIds = B.init<CanisterId>();
    stable let managerCanister = Principal.fromText(Env.accountManager);

    let maxCycleAmount                = 80_000_000_000_000;
    let top_up_amount                 =  2_000_000_000_000;
    private let ic : IC.Self        = actor "aaaaa-aa";
    private let cyclesManagerId : Principal = Principal.fromText("bnz7o-iuaaa-aaaaa-qaaaa-cai");
    private let walletUtils : WalletUtils.WalletUtils = WalletUtils.WalletUtils();
    private let canisterUtils : CanisterUtils.CanisterUtils = CanisterUtils.CanisterUtils();


    public shared ({caller}) func registerContentInfo(contentInfo : ContentData) : async ?(ContentId) {
        // assert(caller == owner or Utils.isManager(caller) or caller == artistBucket);
        let now = Time.now();
        // let videoId = Principal.toText(contentInfo.userId) # "-" # contentInfo.name # "-" # (Int.toText(now));
        switch (Map.get(content, thash, contentInfo.contentId)) {
            case (?_) { throw Error.reject("Content ID already taken")};
            case null { 
                let a = Map.put(content, thash, contentInfo.contentId, contentInfo);

                B.add(contentIds, contentInfo.contentId);
                    // await checkCyclesBalance();
                ?contentInfo.contentId
            };
        }
    };

    public query({caller}) func getAllContentInfo() : async [(ContentId, ContentData)]{
        // assert(caller == owner or Utils.isManager(caller));
        var res = Buffer.Buffer<(ContentId, ContentData)>(2);

        Debug.print("@getCanisterOfContent canisterId: " # debug_show caller);

        for((key, value) in Map.entries(content)){
            var contentId : ContentId = key;
            var contentData : ContentData = value;
            res.add(contentId, contentData);
        };       
        return Buffer.toArray(res);
        // Map.get(content, thash, id);
    };

    public query({caller}) func getAllContentInfoByUserId(userId: UserId) : async [(ContentId, ContentData)]{
        // assert(caller == owner or Utils.isManager(caller));
        var res = Buffer.Buffer<(ContentId, ContentData)>(2);

        for((key, value) in Map.entries(content)){
            if(value.userId == userId) {
                var contentId : ContentId = key;
                var contentData : ContentData = value;
                res.add(contentId, contentData);
            }
        };       
        return Buffer.toArray(res);
        // Map.get(content, thash, id);
    };

    public shared ({caller}) func increasePlayCount(contentId : ContentId) {
        switch(Map.get(content, thash, contentId)){
            case(?canInfo){
                var updatedContentInfo: ContentData = {
                    userId = canInfo.userId;
                    contentId = canInfo.contentId;
                    contentCanisterId = canInfo.contentCanisterId;
                    createdAt = canInfo.createdAt;
                    uploadedAt = canInfo.uploadedAt;
                    playCount = canInfo.playCount + 1;
                    title = canInfo.title;
                    duration = canInfo.duration;
                    size = canInfo.size;
                    chunkCount = canInfo.chunkCount;
                    fileType = canInfo.fileType;
                    thumbnail = canInfo.thumbnail;
                };

                let a = Map.replace(content, thash, contentId, updatedContentInfo);
            };
            case null { };
        };
    };

    public shared({caller}) func removeContent(contentId: ContentId, chunkNum : Nat) : async () {
        switch(Map.get(content, thash, contentId)){
            case(?canInfo){
                assert(caller == canInfo.userId or Utils.isManager(caller));

                let can = actor(Principal.toText(canInfo.contentCanisterId)): actor { 
                    removeContent: (ContentId, Nat) -> async ();
                };
                await can.removeContent(contentId, chunkNum);
                let a = Map.remove(content, thash, contentId);
            };
            case null { };
        };
    };

    public query({caller}) func getCanisterOfContent(contentId: ContentId) : async (?CanisterId){

        Debug.print("all maps: " # debug_show Map.get(content, thash, contentId));
        switch(Map.get(content, thash, contentId)){
            case(?canInfo){
                assert(caller == canInfo.userId or Utils.isManager(caller));
                Debug.print("@getCanisterOfContent canisterId: " # debug_show canInfo.contentCanisterId);
                return ?canInfo.contentCanisterId;
            };
            case null {
                return null
            };
        };
        
    };

    public query({caller}) func getEntriesOfCanisterToContent() : async [(CanisterId, ContentId)]{
        var res = Buffer.Buffer<(CanisterId, ContentId)>(2);
        for((key, value) in Map.entries(content)){
            var contentId : ContentId = key;
            var canisterId : CanisterId = value.contentCanisterId;
            res.add(canisterId, contentId);
        };       
        return Buffer.toArray(res);
    };

    public query({caller}) func getAllContentCanisters() : async [CanisterId]{
        // assert(caller == owner or Utils.isManager(caller) or caller == managerCanister);
        B.toArray(contentCanisterIds);
    };

    public query func getAvailableContentId() : async Nat {
        let size = B.size(contentIds);
        if (size > 0) {
            return size + 1;
        };
        return 1;
    };

    public shared({caller}) func createContent(i : ContentInit) : async ?(contentId : ContentId, contentCanisterId : Principal) {
        Debug.print("@createContent: caller of this function is:\n" # Principal.toText(caller));
        assert(caller == i.userId or Utils.isManager(caller));

        var uploaded : Bool = false;

        let contentUUID : Nat = await getAvailableContentId();

        for(canister in B.vals(contentCanisterIds)){
            Debug.print("canister: " # debug_show canister);

            switch(await getAvailableMemoryCanister(canister)){
                case(?availableMemory){
                if(availableMemory > i.size){

                    let can = actor(Principal.toText(canister)): actor { 
                        createContent: (ContentInit, Nat) -> async ?(ContentId, ContentData);
                    };

                    Debug.print("contentUUID: " # debug_show contentUUID);
                    
                    switch(await can.createContent(i, contentUUID)){
                        case(?(contentId, contentInfo)){ 

                            uploaded := true;

                            Debug.print("uploaded: " # debug_show uploaded);

                            let c = await registerContentInfo(contentInfo);
                            
                            Debug.print("contentInfo: " # debug_show contentInfo);

                            return ?(contentId, canister);
                        };
                        case null { 
                            return null
                        };
                    };
                };
                };
                case null return null;
            };
        };

        if(uploaded == false){
        switch(await createStorageCanister(i.userId)){
            case(?canID){
            B.add(contentCanisterIds, canID);
            let newCan = actor(Principal.toText(canID)): actor { 
                createContent: (ContentInit, Nat) -> async ?(ContentId, ContentData);
            };
            switch(await newCan.createContent(i, contentUUID)){
                case(?(contentId, contentInfo)){ 
                    Debug.print("putting in the mapping contentId: " # debug_show contentId);

                    let c = await registerContentInfo(contentInfo);
                    uploaded := true;
                    return ?(contentId, canID)  
                };
                case null { 
                    return null
                };
            };
            };
            case null return null;
        }
        } else{
             return null;
        }
    };

    public query func cyclesBalance() : async (Nat) {
        // if (not Utils.isManager(caller)) {
        //   throw Error.reject("@cyclesBalance: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
        // };
        return walletUtils.cyclesBalance();
    };

    public shared({caller}) func installCode(canisterId : Principal, owner : Blob, wasmModule : Blob) : async () {
        Debug.print("@installCode: caller is: " # Principal.toText(caller));
        if (not Utils.isManager(caller)) {
            throw Error.reject("@installCode: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
        };
        Debug.print("install code has been initiated");
        await canisterUtils.installCode(canisterId, owner, wasmModule);
    };

    private func createStorageCanister(owner: UserId) : async ?(Principal) {
        await checkCyclesBalance();
        Debug.print("@createStorageCanister: owner (artist) principal: " # debug_show Principal.toText(owner));
        Debug.print("@createStorageCanister: Environment Manager Principal: " # Env.manager[0]);
        Prim.cyclesAdd(1_000_000_000_000);

        var canisterId: ?Principal = null;

        let b = await ArtistContentBucket.ArtistContentBucket(owner, managerCanister, Principal.fromActor(ContentManager));
        canisterId := ?(Principal.fromActor(b));

        switch (canisterId) {
        case null {
            throw Error.reject("@createStorageCanister: Bucket initialisation error");
        };
        case (?canisterId) {

            let self: Principal = Principal.fromActor(ContentManager);

            let controllers: ?[Principal] = ?[canisterId, owner, managerCanister, self, Principal.fromText(Env.manager[0]), cyclesManagerId];

            let cid = { canister_id = Principal.fromActor(ContentManager)};
            Debug.print("@createStorageCanister: IC status: "  # debug_show(await ic.canister_status(cid)));
            
            await ic.update_settings(({canister_id = canisterId; 
            settings = {
                controllers = controllers;
                freezing_threshold = null;
                memory_allocation = null;
                compute_allocation = null;
            }}));
            
            await walletUtils.transferCycles(canisterId, 1_000_000_000_000);

            // let can = actor(Principal.toText(canisterId)): actor { 
            //   initializeCyclesRequester: (Principal, CyclesRequester.TopupRule) -> async ();
            // };

            // // type method = {
            // //   #by_amount : Cycles;
            // //   #to_balance : Cycles;
            // // };

            // let topupRule: CyclesRequester.TopupRule = {
            //   threshold = 1_000_000_000_000;
            //   // method.by_amount = 1_000_000_000_000;

            // };

            // await can.initializeCyclesRequester(managerCanister, topupRule);

        };
        };
        return canisterId;
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

    private func getAvailableMemoryCanister(canisterId: Principal) : async ?Nat{
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

    public shared({caller}) func deleteContentCanister(canisterId: Principal) :  async (Bool){
        // if (not Utils.isManager(caller)) {
        //   throw Error.reject("@deleteContentCanister: Unauthorized access. Caller is not the manager. Caller is: " # Principal.toText(caller));
        // };

        for(canister in B.vals(contentCanisterIds)){
            if(canister == canisterId){
                let index = B.indexOf<Principal>(canisterId, contentCanisterIds, Principal.equal);
                switch(index){
                case(?exists){
                    let j = B.remove(contentCanisterIds, exists);

                    for ((key, value) in Map.entries(content)) {
                        if(value.contentCanisterId == canisterId){
                            Map.delete(content, thash, key);
                        };
                    };

                    let res = await canisterUtils.deleteCanister(?canisterId);
                    return true;

                }; case null return false;
                }

            };
        };
        return false;
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

    public func transferCyclesToThisCanister() : async (){
        let self: Principal = Principal.fromActor(ContentManager);
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
          var version: ?Nat = ?1;
          
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
};

