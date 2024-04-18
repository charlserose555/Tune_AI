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

    let maxCycleAmount                = 80_000_000_000_000;
    let top_up_amount                 =  2_000_000_000_000;


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

    public query func getAvailableContentId() : async Nat {
        let size = B.size(contentIds);
        if (size > 0) {
            return size + 1;
        };
        return 1;
    };
};

