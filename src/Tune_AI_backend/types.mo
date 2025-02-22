import Hash "mo:base/Hash";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Float "mo:base/Float";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import IC "./ic.types";

module Types {

    public type UserId = Principal; 
    public type CanisterId = IC.canister_id;
    
    public type Timestamp = Int;
    
    public type ContentId = Text;
    public type VideoId = Text; // chosen by createVideo
    public type ChunkId = Text; // VideoId # (toText(ChunkNum))
    
    public type ProfilePhoto = Blob; // encoded as a PNG file
    public type CoverPhoto = Blob;

    // public type Thumbnail = Blob; // encoded as a PNG file
    public type ChunkData = Blob; // encoded as ???

    public type FileExtension = {
      #jpeg;
      #jpg;
      #png;
      #gif;
      #svg;
      #mp3;
      #wav;
      #aac;
      #mp4;
      #avi;
    };


    public type ContentInit = {
      userId : UserId;
      title: Text;
      createdAt : Timestamp;      
      chunkCount: Nat;
      fileType: Text;
      size: Nat;
      duration: Nat;
      isReleased: Bool;
      thumbnail: Thumbnail;
    };


    public type ContentData = {
      userId : UserId;
      contentId : Text;
      contentCanisterId: Principal;
      createdAt : Timestamp;
      uploadedAt : Timestamp;
      playCount : Nat;
      title: Text;
      duration: Nat;
      size: Nat;
      chunkCount: Nat;
      fileType: Text;
      isReleased: Bool;
      thumbnail: Thumbnail;
    };

    public type Thumbnail = {
      fileType: Text;
      file: Blob;
    };
    
    public type Trailer = {
      name: Text;
      chunkCount: Nat;
      extension: FileExtension;
      size: Nat;
      file: ?Blob;
    };

    public type FanAccountData = {
        userPrincipal: Principal;
        createdAt: Timestamp;
        // profilePhoto: ?ProfilePhoto;
    };

    public type UserType = {
        #fan;
        #artist;
    };

    public type ArtistAccountData = {
        displayName: Text;
        userName: Text;
        userPrincipal: Principal;
        avatar: ?ProfilePhoto;
        fileType: ?Text;
        createdAt: Timestamp;
        updatedAt: Timestamp;
    };

    public type PrincipalInfo = {
        userPrincipal: Principal;
        createdAt: Timestamp;
    };

    public type StatusRequest = {
        cycles: Bool;
        memory_size: Bool;
        heap_memory_size: Bool;
        version: Bool;
    };

    public type StatusResponse = {
        cycles: ?Nat;
        memory_size: ?Nat;
        heap_memory_size: ?Nat;
        version: ?Nat;
    }; 

    public type StreamingCallbackToken = {
    content_encoding : Text;
    key : Text;
    index : Nat; //starts at 1
    sha256: ?[Nat8];
  };

  public type StreamingCallbackResponse = {
    body : Blob;
    token : ?StreamingCallbackToken;
  };

  public type StreamingCallback = query (StreamingCallbackToken) -> async (StreamingCallbackResponse);

  public type StreamingStrategy = {
    #Callback: {
      token : StreamingCallbackToken;
      callback : StreamingCallback;
    }
  };

  public type HttpRequest = {
    method: Text;
    url: Text;
    headers: [(Text, Text)];
    body: Blob;
  };
  
  public type HttpResponse = {
    status_code: Nat16;
    headers: [(Text, Text)];
    body: Blob;
  };
}