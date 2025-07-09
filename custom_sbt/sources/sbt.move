module 0xbe2bd85369e1d610bbcd43592515ec4215a1cb30c6358ed84ca0e59d354eb362::sbt {
    use std::string::{Self, String};
    use std::signer;
    use std::option;
    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::collection;
    use aptos_token_objects::token;

    /// Collection and Token Metadata
    const COLLECTION_NAME: vector<u8> = b"Developer Badges";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Soulbound NFT badges for active contributors";
    const COLLECTION_URI: vector<u8> = b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main/ecosystem/indexer-grpc/indexer-grpc-utils/collection.png";

    /// Token Metadata
    const TOKEN_NAME: vector<u8> = b"Top Contributor 2025";
    const TOKEN_DESCRIPTION: vector<u8> = b"Awarded to outstanding developers in the Aptos ecosystem";
    const TOKEN_URI: vector<u8> = b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main/ecosystem/indexer-grpc/indexer-grpc-utils/token.png";

    /// Error codes
    const E_NOT_CREATOR: u64 = 1;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct SBTData has key {
        recipient: address,
        minted_at: u64,
    }

    /// Initialize the collection (only needs to be done once)
    public entry fun initialize_collection(creator: &signer) {
        // Create the collection with no royalty and unlimited supply
        collection::create_unlimited_collection(
            creator,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            option::none(), // No royalty
            string::utf8(COLLECTION_URI),
        );
    }

    /// Mint an SBT directly to any address (no recipient setup required)
    public entry fun mint_sbt(creator: &signer, recipient: address) {
        let creator_addr = signer::address_of(creator);
        
        // Create a unique token name for this recipient
        let unique_token_name = create_unique_token_name(recipient);
          // Create the token
        let constructor_ref = token::create_named_token(
            creator,
            string::utf8(COLLECTION_NAME),
            string::utf8(TOKEN_DESCRIPTION),
            unique_token_name,
            option::none(), // No royalty
            string::utf8(TOKEN_URI),
        );

        // Get the token object and transfer ownership to recipient FIRST
        let token_object = object::object_from_constructor_ref<token::Token>(&constructor_ref);
        object::transfer(creator, token_object, recipient);

        // Now make the token non-transferable (soulbound) after the initial transfer
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        object::disable_ungated_transfer(&transfer_ref);

        // Store additional SBT data
        let token_signer = object::generate_signer(&constructor_ref);
        move_to(&token_signer, SBTData {
            recipient,
            minted_at: aptos_framework::timestamp::now_microseconds(),
        });
    }    /// Helper function to create unique token names
    fun create_unique_token_name(recipient: address): String {
        let name = string::utf8(TOKEN_NAME);
        string::append(&mut name, string::utf8(b" #"));
        
        // Simple unique identifier using just timestamp as string
        let timestamp = aptos_framework::timestamp::now_microseconds();
        
        // Convert timestamp to a simple numeric string representation
        // For simplicity, just use the last few digits
        let unique_id = timestamp % 1000000; // Get last 6 digits
        
        // Convert to bytes in a safe way
        if (unique_id >= 100000) {
            string::append(&mut name, string::utf8(b"1"));
        };
        if (unique_id >= 10000) {
            string::append(&mut name, string::utf8(b"0"));
        };
        
        string::append(&mut name, string::utf8(b"ID"));
        
        name
    }

    /// View function to check SBT data
    #[view]
    public fun get_sbt_data(token_address: address): (address, u64) acquires SBTData {
        let sbt_data = borrow_global<SBTData>(token_address);
        (sbt_data.recipient, sbt_data.minted_at)
    }
}
