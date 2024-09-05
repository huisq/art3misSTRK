
use snforge_std::{ declare, ContractClassTrait, start_cheat_caller_address };
use starknet::{ ContractAddress, contract_address_const};

use art3mis::contract::ITarotDispatcher;
use art3mis::contract::ITarotDispatcherTrait;
use openzeppelin_testing::{declare_and_deploy};


// pub fn OWNER() -> ContractAddress {
//     contract_address_const::<'OWNER'>()
// }


fn setup_dispatcher() -> ITarotDispatcher {
    let mut calldata = ArrayTrait::new();
    
    let address = declare_and_deploy("Tarot", calldata); //mod name

    start_cheat_caller_address(address, contract_address_const::<'OWNER'>());
    ITarotDispatcher { contract_address: address}
}


#[test]
fn test_dispatch() {
    let dispatcher = setup_dispatcher();
    let name = dispatcher.get_name();
    println!("event name: {name}");
}