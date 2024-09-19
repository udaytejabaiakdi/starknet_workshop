#[starknet::interface]
trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
}
#[starknet::interface]
trait IKillSwitch<TContractState> {
    fn is_active(self: @TContractState) -> bool;
}


#[starknet::contract]
pub mod counter_contract {
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;
    use super::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);


    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;
 

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)] // Updated derive macro
    pub enum Event {
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)] // Updated derive macro
    pub struct CounterIncreased {
        #[key]
        pub counter: u32
    }
    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, kill_switch: ContractAddress,initial_owner: ContractAddress) {
        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch);
        self.ownable.initializer(initial_owner);
    }


    #[abi(embed_v0)]
    impl CounterContract of super::ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }
        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();
            
            let kill_switch_dispatcher = IKillSwitchDispatcher {
                contract_address: self.kill_switch.read(),
            };

            assert!(!kill_switch_dispatcher.is_active(), "Kill Switch is active");

            let mut curr_value: u32 = self.counter.read();
            curr_value += 1;
            self.counter.write(curr_value);

            self.emit(Event::CounterIncreased(CounterIncreased { counter: self.counter.read() }));
        }
    }

}