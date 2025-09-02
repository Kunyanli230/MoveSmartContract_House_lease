
module my_fist_contract::simple_nft {

    use sui::transfer::{public_transfer};

    /// An object that contains an arbitrary string
    public struct Hero has key, store {
        id: UID,
    }

    #[lint_allow(self_transfer)]
    public fun mint( ctx: &mut TxContext) {
        let object = Hero {
            id: object::new(ctx)
        };
        public_transfer(object, tx_context::sender(ctx));
    }

}
