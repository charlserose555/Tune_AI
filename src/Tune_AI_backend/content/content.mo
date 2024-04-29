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
import Utils                "../utils/utils";
import WalletUtils          "../utils/wallet.utils";
import S                    "mo:base/ExperimentalStableMemory";
import IC                   "../ic.types";
import Option               "mo:base/Option";

actor class ArtistContentBucket(owner: Principal, manager: Principal, contentManager:Principal) = this {

  type UserId                    = T.UserId;
  type ContentInit               = T.ContentInit;
  type ContentId                 = T.ContentId;
  type ContentData               = T.ContentData;
  type ChunkId                   = T.ChunkId;
  type CanisterId                = T.CanisterId;
  type ChunkData                 = T.ChunkData;
  type StatusRequest             = T.StatusRequest;
  type StatusResponse            = T.StatusResponse;
  type Thumbnail                 = T.Thumbnail;
  type Trailer                   = T.Trailer;
  type CanisterStatus            = IC.canister_status_response;
  type HttpRequest               = T.HttpRequest;
  type HttpResponse              = T.HttpResponse;
  type StreamingCallbackToken    = T.StreamingCallbackToken;
  type StreamingCallbackResponse = T.StreamingCallbackResponse;
  type StreamingStrategy         = T.StreamingStrategy;

  let { ihash; nhash; thash; phash; calcHash } = Map;

  stable var canisterOwner: Principal = owner;
  stable var managerCanister: Principal = manager;
  stable var contentManagerCanister: Principal = contentManager;

  stable var initialised: Bool = false;
  stable var MAX_CANISTER_SIZE: Nat =     68_700_000_000; // <-- approx. 64GB
  stable var CYCLE_AMOUNT : Nat     =  100_000_000_000; // minimum amount of cycles needed to create new canister 
  let maxCycleAmount                = 80_000_000_000_000; // canister cycles capacity 
  let top_up_amount                 = 1_000_000_000_000;
  var VERSION: Nat                  = 1; 

  private let canisterUtils : CanisterUtils.CanisterUtils = CanisterUtils.CanisterUtils();
  private let walletUtils : WalletUtils.WalletUtils = WalletUtils.WalletUtils();

  stable let content = Map.new<Text, ContentData>(thash);
  stable let chunksData = Map.new<ChunkId, ChunkData>(thash);



// #region - CREATE & UPLOAD CONTENT
  public shared({caller}) func createContent(i : ContentInit, contentUUID : Nat) : async ?(ContentId, ContentData) {
    assert(caller == contentManager or Utils.isManager(caller));
    let now = Time.now();
    // let videoId = Principal.toText(i.userId) # "-" # i.name # "-" # (Int.toText(now));
    switch (Map.get(content, thash, Nat.toText(contentUUID))) {
    case (?_) { throw Error.reject("Content ID already taken")};
    case null { 
      let contentData = {
                          userId = i.userId;
                          contentId = Nat.toText(contentUUID);
                          userCanisterId = i.userCanisterId;
                          contentCanisterId = Principal.fromActor(this);
                          title = i.title;
                          createdAt = i.createdAt;
                          fileType = i.fileType;
                          duration = i.duration;
                          uploadedAt = now;
                          playCount = 0;
                          chunkCount = i.chunkCount;
                          size = i.size;
                          thumbnail = i.thumbnail;
                        };

       let a = Map.put(content, thash, Nat.toText(contentUUID), contentData);

        // await checkCyclesBalance();
       ?(Nat.toText(contentUUID), contentData)
     };
    }
  };

  public shared({caller}) func putContentChunk(contentId : ContentId, chunkNum : Nat, chunkData : Blob) : async Nat{
    assert(caller == owner or Utils.isManager(caller));
    let a = Map.put(chunksData, thash, chunkId(contentId, chunkNum), chunkData);

    return chunkNum;
  };


  public query({caller}) func getContentChunk(contentId : ContentId, chunkNum : Nat) : async ?Blob {
    // assert(caller == owner or Utils.isManager(caller));
    Map.get(chunksData, thash, chunkId(contentId, chunkNum));
  };

  private func chunkId(contentId : ContentId, chunkNum : Nat) : ChunkId {
    contentId # (Nat.toText(chunkNum))
  };


  public shared({caller}) func removeContent(contentId: ContentId, chunkNum : Nat) : async () {
    assert(caller == owner or Utils.isManager(caller));
    let a = Map.remove(chunksData, thash, chunkId(contentId, chunkNum));
    let b = Map.remove(content, thash, contentId);
  };

  public query({caller}) func getContentInfo(id: ContentId) : async ?ContentData{
    // assert(caller == owner or Utils.isManager(caller));
    let a = Map.get(content, thash, id);

    return a;
  };

  public query({caller}) func getAllContentInfo(id: ContentId) : async [(ContentId, ContentData)]{
    // assert(caller == owner or Utils.isManager(caller));
    var res = Buffer.Buffer<(ContentId, ContentData)>(2);
    for((key, value) in Map.entries(content)){
      var contentId : ContentId = key;
      var contentData : ContentData = value;
      res.add(contentId, contentData);
    };       
    return Buffer.toArray(res);
    // Map.get(content, thash, id);
  };

  public query func streamingCallback(token:StreamingCallbackToken): async StreamingCallbackResponse {
    Debug.print("Sending chunk " # debug_show(token.key) # debug_show(token.index));
    let body:Blob = switch(Map.get(chunksData, thash, chunkId(token.key, token.index))) {
      case (?b) b;
      case (null) "Not Found";
    };
    let next_token:?StreamingCallbackToken = switch(Map.get(chunksData, thash, chunkId(token.key, token.index+1))){
      case (?nextbody) ?{
        content_encoding=token.content_encoding;
        key = token.key;
        index = token.index+1;
        sha256 = null;
      };
      case (null) null;
    };

    {
      body=body;
      token=next_token;
    };
  };

  public query func http_request(req: HttpRequest) : async HttpResponse {
      let fields:[Text]  = Iter.toArray<Text>(Text.split(req.url, #text("&contentId=")));
      Debug.print("contentId " # debug_show(fields[1]));
      let contentId:ContentId = fields[1];

      let result:?(Text, Text) = Array.find<(Text, Text)>(req.headers, func((name, _)) { name == "range" });
      Debug.print("result: " # debug_show(result));
        switch(result) {
          case (?(_, rangeHeader)) {
            return handleRangeRequest(rangeHeader, contentId);
          };
          case (_) {
            return {status_code = 206;
                    headers = [
                        ("Content-Range", "bytes " # Nat.toText(0) # "-" # Nat.toText(12) # "/" # Nat.toText(5)),
                        ("Content-Type", "audio/mpeg"),
                        ("Accept-Ranges", "bytes")
                    ];
                    body = Blob.fromArray([72, 101, 108, 108, 111]);}
          }
      };       
  };

  private func parseRangeHeader(range: Text): (Nat, Nat) {
      // Parse the range header, expected format: "bytes=start-end"
      let parts = Iter.toArray<Text>(Text.split(range, #text("=")))[1];
      let rangeParts = Iter.toArray<Text>(Text.split(parts, #text("-")));
      var start:?Nat = ?0;
      var end:?Nat = ?0;
      start:= Nat.fromText(rangeParts[0]);
      end:= Nat.fromText(rangeParts[1]);

      return (Option.get(start, 0), Option.get(end, (Option.get(start, 0) + 511_999)));
  };

  private func handleRangeRequest(rangeHeader: Text, contentId: ContentId) : HttpResponse {
    var contentSize:Nat = 0;
    var startValue:Nat = 0;
    var endValue:Nat = 0;
    var mainBlobArray: [Nat8] = [];

    let _ = do? {        
      let contentInfo:ContentData = Map.get(content, thash, contentId)!;
      contentSize := contentInfo.size;
      let (start, end) = parseRangeHeader(rangeHeader);

      startValue := start;
      endValue := Nat.min(end, contentSize - 1);      

      Debug.print("start: " # debug_show(start));
      Debug.print("end: " # debug_show(end));

      var val:[Nat8] = [];
      let startChunkIndex = start / 512_000; // 500KB per chunk
      let endChunkIndex = end / 512_000;

      let startOffset = start % 512_000;
      let endOffset = end % 512_000 + 1;

      var fullBlob:Blob = Blob.fromArray([]);
      var fullBlobBuffer = Buffer.Buffer<[Nat8]>(endChunkIndex - startChunkIndex + 1);

      Debug.print("startChunkIndex: " # debug_show(startChunkIndex));
      Debug.print("endChunkIndex: " # debug_show(endChunkIndex));

      var fullBlobArray:[Nat8] = [];

      for (i in Iter.range(startChunkIndex, endChunkIndex)) {
        Debug.print("rangeIndex: " # debug_show(i));

        switch (Map.get(chunksData, thash, chunkId(contentId, i + 1))) {
          case (?chunk) {
            let chunkArray:[Nat8] = Blob.toArray(chunk);
            fullBlobBuffer.add(chunkArray);

            let size1 = fullBlobArray.size();
            let size2 = chunkArray.size();

            fullBlobArray :=  Prim.Array_tabulate<Nat8>(
              size1 + size2,
              func i {
                if (i < size1) {
                  fullBlobArray[i]
                } else {
                  chunkArray[i - size1]
                }
              }
            );
          };

          case (null) {
          };
        };
      };

      Debug.print("full-content-Length: " # debug_show(Array.size(fullBlobArray)));

      let length:Nat = endValue - startValue + 1;

      Debug.print("Length: " # debug_show(length));
      Debug.print("startOffset: " # debug_show(startOffset));

      mainBlobArray := Array.subArray(fullBlobArray, startOffset, length);
      Debug.print("Content-Length: " # debug_show(Array.size(mainBlobArray)));
      Debug.print("Content-Size: " # debug_show(contentSize));
    };

    return {
        status_code = 206;
        headers = [
            ("Content-Range", "bytes " # Nat.toText(startValue) # "-" # Nat.toText(endValue) # "/" # Nat.toText(contentSize)),
            ("Content-Type", "audio/mpeg"),
            ("Content-Length", Nat.toText(Array.size(mainBlobArray))),
            ("Accept-Ranges", "bytes")
        ];
        body = Blob.fromArray(mainBlobArray);
    };
  };
// #endregion

// #region - UTILS
  public shared({caller}) func checkCyclesBalance () : async(){
    assert(caller == owner or Utils.isManager(caller) or caller == Principal.fromActor(this));
    Debug.print("@checkCyclesBalance: creator of this smart contract:\n" # debug_show manager);
    let bal = getCurrentCycles();
    Debug.print("@checkCyclesBalance: Cycles Balance After Canister Creation:\n" # debug_show bal);
    if(bal < CYCLE_AMOUNT){
       await transferCyclesToThisCanister();
    };
  };

   public query func getCurrentCyclesBalance(): async Nat {
    Cycles.balance();
  };




  // public func transferCyclesToThisCanister() : async (){
  //   let self: Principal = Principal.fromActor(this);

  //   let can = actor(Principal.toText(managerCanister)): actor { 
  //     transferCyclesToContentCanister: (Principal, Principal, Nat) -> async ();
  //   };
  //   let accepted = await wallet_receive();
  //   await can.transferCyclesToContentCanister(artistBucket, self, Nat64.toNat(accepted.accepted));
  // };


  public func transferCyclesToThisCanister() : async (){
    let self: Principal = Principal.fromActor(this);
    let can = actor(Principal.toText(managerCanister)): actor { 
      transferCyclesToCanister: (Principal, Nat) -> async ();
    };
    let accepted = await wallet_receive();
    await can.transferCyclesToCanister(self, Nat64.toNat(accepted.accepted));
  };




  public shared({caller}) func changeCycleAmount(amount: Nat) : (){
    if (not Utils.isManager(caller)) {
      throw Error.reject("@changeCycleAmount: Unauthorized access. Caller is not the manager. caller is:\n" # Principal.toText(caller));
    };
    CYCLE_AMOUNT := amount;
  };




  public shared({caller}) func changeCanisterSize(newSize: Nat) : (){
    if (not Utils.isManager(caller)) {
      throw Error.reject("@changeCanisterSize: Unauthorized access. Caller is not the manager. caller is:\n" # Principal.toText(caller));
    };
    MAX_CANISTER_SIZE := newSize;
  };




  public shared ({caller}) func transferFreezingThresholdCycles() : async () {
    assert(Utils.isManager(caller) or caller == owner or caller == contentManagerCanister);
    // if (not Utils.isManager(caller)) {
    //   throw Error.reject("@transferFreezingThresholdCycles: Unauthorized access. Caller is not a manager. caller is: \n" # Principal.toText(caller));
    // };

    await walletUtils.transferFreezingThresholdCycles(contentManagerCanister);
  };



  private func wallet_receive() : async { accepted: Nat64 } {
    let available = Cycles.available();
    let accepted = Cycles.accept(Nat.min(available, top_up_amount));
    // let accepted = Cycles.accept(top_up_amount);
    { accepted = Nat64.fromNat(accepted) };
  };



  public query({caller}) func getPrincipalThis() :  async (Principal){
    if (not Utils.isManager(caller)) {
      throw Error.reject("@getPrincipalThis: Unauthorized access. Caller is not a manager. caller is: \n" # Principal.toText(caller));
    };
    Principal.fromActor(this);
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
    // assert(caller == owner or Utils.isManager(caller) or caller == artistBucket);
        switch(request) {
            case (null) {
                return null;
            };
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
        };
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

// #endregion
  
}