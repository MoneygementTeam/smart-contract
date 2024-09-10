module mint_nft::minting {
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::aptos_account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;
    use aptos_std::ed25519;
    use aptos_token::token::{Self, TokenDataId};
    use aptos_framework::resource_account;
    #[test_only]
    use aptos_framework::account::create_account_for_test;
    use aptos_std::ed25519::ValidatedPublicKey;

    struct TokenMintingEvent has drop, store {
        token_receiver_address: address,
        token_data_id: TokenDataId,
    }

    struct ModuleData has key {
        public_key: ed25519::ValidatedPublicKey,
        signer_cap: account::SignerCapability,
        expiration_timestamp: u64,
        minting_enabled: bool,
        public_price:u64,
        presale_price:u64,
        current_supply:u64,
        maximum_supply:u64,
        publicsale_status:bool,
        presale_status:bool,
        token_minting_events: EventHandle<TokenMintingEvent>,
        whitelist_only:bool,
        whitelist_addr:vector<address>,
        royalty_account_address: address,
        partner_account_address: address,
        resource_account_address:address,
        royalty_points_denominator:u64,
        partner_numerator:u64,
        royalty_points_numerator:u64,
        collection_name:String,
        description:String,
        token_name:String,
        token_uri:String,
        token_uri_filetype:String,
    }

    struct MintProofChallenge has drop {
        receiver_account_sequence_number: u64,
        receiver_account_address: address,
        token_data_id: TokenDataId,
    }

    const ENOT_AUTHORIZED: u64 = 1;
    const ECOLLECTION_EXPIRED: u64 = 2;
    const EMINTING_DISABLED: u64 = 3;
    const EWRONG_PUBLIC_KEY: u64 = 4;
    const EINVALID_SCHEME: u64 = 5;
    const NOT_FOUND: u64 = 6;
    const EINVALID_PROOF_OF_KNOWLEDGE: u64 = 7;

    fun init_module(resource_account: &signer) {
        let hardcoded_pk = "";
        init_module_with_admin_public_key(resource_account, hardcoded_pk);
    }

    fun init_module_with_admin_public_key(resource_account: &signer, pk_bytes: vector<u8>) {
        let collection_name = string::utf8(b"Moneygement NFT Collection");
        let description = string::utf8(b"This is a Moneygement NFT colleciton.");
        let collection_uri = string::utf8(b"");
        let token_name = string::utf8(b"Moneygement #");
        let token_uri = string::utf8(b"");
        let token_uri_filetype = string::utf8(b".json");
        let expiration_timestamp = 1725943584;
        let public_price = 1000000;
        let presale_price = 1000000;
        let whitelist_addr = vector::empty<address>();
        let whitelist_only =false;
        let royalty_points_denominator = 10000;
        let royalty_points_numerator = 800;

        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_account, @source_addr);
        let resource_signer = account::create_signer_with_capability(&resource_signer_cap);
        let maximum_supply = 100;
        let current_supply = 0;
        let mutate_setting = vector<bool>[ false, false, false ];
        let resource_account_address = signer::address_of(&resource_signer);
        let royalty_account_address = @admin_addr;
        let partner_account_address = @aptosnftstudio_addr;
        let partner_numerator = 100;
        token::create_collection(&resource_signer, collection_name, description, collection_uri, maximum_supply, mutate_setting);

        let public_key = std::option::extract(&mut ed25519::new_validated_public_key_from_bytes(pk_bytes));

        move_to(resource_account, ModuleData {
            public_key,
            signer_cap: resource_signer_cap,
            expiration_timestamp,
            maximum_supply,
            current_supply,
            royalty_account_address,
            resource_account_address,
            partner_account_address,
            partner_numerator,
            public_price,
            presale_price,
            royalty_points_denominator,
            minting_enabled: true,
            presale_status:false,
            publicsale_status:true,
            whitelist_addr,
            whitelist_only,
            token_name,
            token_uri,
            collection_name,
            description,
            token_uri_filetype,
            royalty_points_numerator,
            token_minting_events: account::new_event_handle<TokenMintingEvent>(&resource_signer),
        });
    }

    public entry fun set_whitelist_only(caller: &signer, whitelist_only: bool) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.whitelist_only = whitelist_only;
    }

    public entry fun set_minting_enabled(caller: &signer, minting_enabled: bool) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.minting_enabled = minting_enabled;
    }

    public entry fun set_presale_status(caller: &signer, presale_status: bool) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.presale_status = presale_status;
    }

    public entry fun set_presale_price(caller: &signer, presale_price: u64) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.presale_price = presale_price;
    }

    public entry fun set_publicsale_status(caller: &signer, publicsale_status: bool) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.publicsale_status = publicsale_status;
    }

    public entry fun set_public_price(caller: &signer, public_price: u64) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.public_price = public_price;
    }


    public entry fun set_timestamp(caller: &signer, expiration_timestamp: u64) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.expiration_timestamp = expiration_timestamp;
    }

    public entry fun set_max_supply(caller: &signer, maximum_supply: u64) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.maximum_supply = maximum_supply;
    }

    public entry fun set_public_key(caller: &signer, pk_bytes: vector<u8>) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.public_key = std::option::extract(&mut ed25519::new_validated_public_key_from_bytes(pk_bytes));
    }

    public entry fun set_whitelist_address(caller: &signer, whitelist_addr:vector<address>) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.whitelist_addr = whitelist_addr;
    }

    public entry fun check_whitelist_address(_addr:address) acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        let whitelist_addresses = module_data.whitelist_addr;
        let a = vector::contains(&whitelist_addresses,&_addr);
        assert!(a == true, error::permission_denied(NOT_FOUND));
    }

    public entry fun set_royalty_account_address(caller: &signer, _addr:address) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.royalty_account_address = _addr;
    }


    public entry fun set_partner_account_address(caller: &signer, _addr:address) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.partner_account_address = _addr;
    }

    public entry fun set_partner_numerator(caller: &signer, _numberator:u64) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.partner_numerator = _numberator;
    }

    public entry fun mint_nft(receiver: &signer, quantity: u64) acquires ModuleData {
        let receiver_addr = signer::address_of(receiver);

        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        assert!(timestamp::now_seconds() < module_data.expiration_timestamp, error::permission_denied(ECOLLECTION_EXPIRED));
        assert!(module_data.current_supply + quantity <= module_data.maximum_supply, error::permission_denied(EMINTING_DISABLED));
        assert!(module_data.minting_enabled, error::permission_denied(EMINTING_DISABLED));
        assert!(module_data.presale_status || module_data.publicsale_status, error::permission_denied(EMINTING_DISABLED));

        let mint_fee = if (module_data.presale_status) module_data.presale_price else module_data.public_price;

        if (module_data.whitelist_only) {
            let whitelist_addresses = module_data.whitelist_addr;
            let a = vector::contains(&whitelist_addresses,&receiver_addr);
            assert!(a == true, error::permission_denied(NOT_FOUND));
        };

        if (module_data.partner_account_address == @admin_addr) { 
            aptos_account::transfer(receiver, @admin_addr, mint_fee * quantity);
        } else {
            let _denominator:u64 = module_data.royalty_points_denominator;
            let _partner_numerator:u64 = module_data.partner_numerator;
            let _totalfee: u64 = mint_fee * quantity;

            let _partnersplit: u64 = (copy _totalfee * copy _partner_numerator) / copy _denominator;
            aptos_account::transfer(receiver, module_data.partner_account_address, _partnersplit);

            let _adminsplit: u64 = copy _totalfee - copy _partnersplit;
            aptos_account::transfer(receiver, @admin_addr, _adminsplit);
        };
            let startingid = module_data.current_supply;

            let i: u64 = 1;
            while (i <= quantity) {

                let _token_name = module_data.token_name;
                let _token_uri = module_data.token_uri;

                let supply = to_string(startingid + i);
                string::append(&mut _token_name, supply);
                string::append(&mut _token_uri, supply);
                string::append(&mut _token_uri, module_data.token_uri_filetype);

                let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);

                let token_data_id = token::create_tokendata(
                    &resource_signer,
                    module_data.collection_name,
                    _token_name,
                    module_data.description,
                    1,
                    _token_uri,
                    module_data.royalty_account_address,
                    module_data.royalty_points_denominator,
                    module_data.royalty_points_numerator,

                    token::create_token_mutability_config(
                        &vector<bool>[ true, false, true, true, true ]
                    ),
                    vector::empty<String>(),
                    vector::empty<vector<u8>>(),
                    vector::empty<String>(),
                );

                let token_id = token::mint_token(&resource_signer, token_data_id, 1);
                token::direct_transfer(&resource_signer, receiver, token_id, 1);

                event::emit_event<TokenMintingEvent>(
                    &mut module_data.token_minting_events,
                    TokenMintingEvent {
                        token_receiver_address: receiver_addr,
                        token_data_id: token_data_id,
                    }
                );
                i = i + 1;
                module_data.current_supply = module_data.current_supply + 1;
            }
    }

    fun verify_proof_of_knowledge(receiver_addr: address, mint_proof_signature: vector<u8>, token_data_id: TokenDataId, public_key: ValidatedPublicKey) {
        let sequence_number = account::get_sequence_number(receiver_addr);

        let proof_challenge = MintProofChallenge {
            receiver_account_sequence_number: sequence_number,
            receiver_account_address: receiver_addr,
            token_data_id,
        };

        let signature = ed25519::new_signature_from_bytes(mint_proof_signature);
        let unvalidated_public_key = ed25519::public_key_to_unvalidated(&public_key);
        assert!(ed25519::signature_verify_strict_t(&signature, &unvalidated_public_key, proof_challenge), error::invalid_argument(EINVALID_PROOF_OF_KNOWLEDGE));
    }

    fun to_string(value: u64): String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        string::utf8(buffer)
    }
}
