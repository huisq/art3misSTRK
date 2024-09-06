use starknet::ContractAddress;

#[starknet::interface]
pub trait IPragmaVRF<TContractState> {
    fn get_last_random_number(self: @TContractState) -> felt252;
    fn request_randomness_from_pragma(
        ref self: TContractState,
        seed: u64,
        callback_address: ContractAddress,
        callback_fee_limit: u128,
        publish_delay: u64,
        num_words: u64,
        calldata: Array<felt252>
    );
    fn receive_random_words(
        ref self: TContractState,
        requester_address: ContractAddress,
        request_id: u64,
        random_words: Span<felt252>,
        calldata: Array<felt252>
    );
    fn withdraw_extra_fee_fund(ref self: TContractState, receiver: ContractAddress);
}

#[starknet::interface]
pub trait ITarot<TContractState> {
    fn get_name(self: @TContractState) -> ByteArray;
    fn get_token_uri(self: @TContractState, token_id: u256) -> ByteArray;
    fn shuffle_deck(ref self: TContractState, seed: u64);
    fn draw_card(self: @TContractState) -> ByteArray;
    fn mint(ref self: TContractState, token_uri: u256);
}

#[starknet::contract]
pub mod Tarot {
    use openzeppelin_token::erc721::interface::ERC721ABI;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use core::starknet::{
        ContractAddress, contract_address_const, get_block_number, get_caller_address, get_contract_address
    };
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait
    };
    use pragma_lib::abi::{IRandomnessDispatcher, IRandomnessDispatcherTrait};
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;

    use art3mis::helper::{convert1, convert2, convert3};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // ERC721 Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        name: ByteArray,
        base_uri: ByteArray,
        cards: Vec<ByteArray>,
        minted: usize,
        min_block_number_storage: u64,
        pragma_vrf_contract_address: ContractAddress,
        last_random_number: felt252,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    const CALLBACK_LIMIT: u128 = 1000;
    const PUBLISH_DELAY: u64 = 1;

    #[constructor]
    fn constructor(
        ref self: ContractState,
    ) {
        self.name.write("Art3misTarot");
        self.base_uri.write("ipfs://bafybeifrqo4oorpn2y2l7vy5y4v4tqebvho5q5hg5rfsx2rafzng3u556q/");
        self.cards.append().write("0 The Fool");
        self.cards.append().write("I The Magician");
        self.cards.append().write("II The High Priestess");
        self.cards.append().write("III The Empress");
        self.cards.append().write("IV The Emperor");
        self.cards.append().write("V The Hierophant");
        self.cards.append().write("VI The Lovers");
        self.cards.append().write("VII The Chariot");
        self.cards.append().write("VIII Strength");
        self.cards.append().write("IX The Hermit");
        self.cards.append().write("X The Wheel of Fortune");
        self.cards.append().write("XI Justice");
        self.cards.append().write("XII The Hanged Man");
        self.cards.append().write("XIII Death");
        self.cards.append().write("XIV Temperance");
        self.cards.append().write("XV The Devil");
        self.cards.append().write("XVI The Tower");
        self.cards.append().write("XVII The Star");
        self.cards.append().write("XVIII The Moon");
        self.cards.append().write("XIX The Sun");
        self.cards.append().write("XX Judgement");
        self.cards.append().write("XXI The Worl");
        let vrf: ContractAddress = 0x60c69136b39319547a4df303b6b3a26fab8b2d78de90b6bd215ce82e9cb515c.try_into().unwrap();
        self.pragma_vrf_contract_address.write(vrf);
        self.erc721.initializer(self.name.read(), "AT", self.base_uri.read());
    }

    #[abi(embed_v0)]
    impl TarotImpl of super::ITarot<ContractState> {
        fn get_name(self: @ContractState) -> ByteArray {
            self.name.read()
        }
        fn get_token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.erc721.tokenURI(token_id)
        }

        fn shuffle_deck(ref self: ContractState, seed: u64) {
            self.request_randomness_from_pragma(seed, get_contract_address(), CALLBACK_LIMIT, 1, 1, array![]);
        }

        fn draw_card(self: @ContractState) -> ByteArray {
            let index1: u64 = self.last_random_number.read().try_into().unwrap() %  21;
            let index2: usize = self.last_random_number.read().try_into().unwrap() %  1;
            let mut output: ByteArray = "";
            let mut card = self.cards.at(index1).read();
            output.append(@card);
            if(index2 == 1){ //upright
                output.append(@", upright");
            };
            output
        }

        fn mint(ref self: ContractState, token_uri: u256){
            self.erc721.mint(get_caller_address(), token_uri);
            self.minted.write(self.minted.read() + 1);
        }
    }

    #[abi(embed_v0)]
    impl PragmaVRFOracle of super::IPragmaVRF<ContractState> {
        fn get_last_random_number(self: @ContractState) -> felt252 {
            let last_random = self.last_random_number.read();
            last_random
        }

        fn request_randomness_from_pragma(
            ref self: ContractState,
            seed: u64,
            callback_address: ContractAddress,
            callback_fee_limit: u128,
            publish_delay: u64,
            num_words: u64,
            calldata: Array<felt252>
        ) {

            let randomness_contract_address = self.pragma_vrf_contract_address.read();
            let randomness_dispatcher = IRandomnessDispatcher {
                contract_address: randomness_contract_address
            };
            let compute_fees = randomness_dispatcher.compute_premium_fee(get_caller_address());
            // Approve the randomness contract to transfer the callback fee
            // You would need to send some ETH to this contract first to cover the fees
            let eth_dispatcher = ERC20ABIDispatcher {
                contract_address: contract_address_const::<
                    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
                >() // ETH Contract Address
            };
            eth_dispatcher
                .approve(
                    randomness_contract_address,
                    (callback_fee_limit + compute_fees + callback_fee_limit / 5).into()
                );

            // Request the randomness
            randomness_dispatcher
                .request_random(
                    seed, callback_address, callback_fee_limit, publish_delay, num_words, calldata
                );

            let current_block_number = get_block_number();
            self.min_block_number_storage.write(current_block_number + publish_delay);
        }

        fn receive_random_words(
            ref self: ContractState,
            requester_address: ContractAddress,
            request_id: u64,
            random_words: Span<felt252>,
            calldata: Array<felt252>
        ) {
            // Have to make sure that the caller is the Pragma Randomness Oracle contract
            let caller_address = get_caller_address();
            assert(
                caller_address == self.pragma_vrf_contract_address.read(),
                'caller not randomness contract'
            );
            // and that the current block is within publish_delay of the request block
            let current_block_number = get_block_number();
            let min_block_number = self.min_block_number_storage.read();
            assert(min_block_number <= current_block_number, 'block number issue');

            let random_word = *random_words.at(0);
            self.last_random_number.write(random_word);
        }

        fn withdraw_extra_fee_fund(ref self: ContractState, receiver: ContractAddress) {
            self.ownable.assert_only_owner();
            let eth_dispatcher = ERC20ABIDispatcher {
                contract_address: contract_address_const::<
                    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
                >() // ETH Contract Address
            };
            let balance = eth_dispatcher.balance_of(get_contract_address());
            eth_dispatcher.transfer(receiver, balance);
        }
    }
}

