
module HouseLease::rental_platform {
    use std::string;
    use std::option::{Self, Option};
    use std::vector;

    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID, ID};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::sui::SUI;

    //
    // -------------------- Constants & Errors --------------------
    //
    /// Platform takes 100% of the advertised "deposit" you compute from monthly_rent.
    /// Adjust if you want dynamic rules (e.g., 2 months, etc.).
    const DEPOSIT_PERCENT: u64 = 100;

    // damage levels
    const DAMAGE_LEVEL_UNKNOWN: u8 = 255;
    const DAMAGE_LEVEL_0: u8 = 0;
    const DAMAGE_LEVEL_1: u8 = 1;
    const DAMAGE_LEVEL_2: u8 = 2;
    const DAMAGE_LEVEL_3: u8 = 3;

    // inspection review flags
    const WAITING_FOR_REVIEW: u8 = 0;
    const REVIEWED: u8 = 1;

    // error codes
    const ENoPermission: u64 = 1;
    const EDamageIncorrect: u64 = 2;
    const ETenancyIncorrect: u64 = 3;
    const EInvalidNotice: u64 = 4;
    const EInvalidHouse: u64 = 5;
    const EInvalidSuiAmount: u64 = 6;
    const EWrongParams: u64 = 7;
    const EInspectionReviewed: u64 = 8;
    const EInvalidDeposit: u64 = 9;
    const EInsufficientBalance: u64 = 10;

    //
    // -------------------- Data Structures --------------------
    //
    public struct RentalPlatform has key {
        // uid of the RentalPlatform object
        id: UID,
        // deposit stored on the rental platform, key is house object id,value is the amount of deposit
        deposit_pool: Table<ID, u64>,
        // pooled SUI balance that actually holds the deposit coins
        balance: Balance<SUI>,
        // rental notices on the platform, key is house object id
        notices: Table<ID, RentalNotice>,
        // owner of platform
        owner: address,
    }

    // presents Rental platform administrator
    public struct Admin has key, store {
        // uid of admin object
        id: UID,
    }

    // If the landlord wants to rent out a house, they first need to issue a rental notice
    public struct RentalNotice has key, store {
        // uid of the RentalNotice object
        id: UID,
        // the amount of gas to be paid per month
        monthly_rent: u64,
        // the amount of gas to be deposited
        deposit: u64,
        // the id of the house object
        house_id: ID,
        // account address of landlord
        landlord: address,
    }

    // present a house object
    public struct House has key {
        // uid of the house object
        id: UID,
        // The square of the house area
        area: u64,
        // The owner of the house
        owner: address,
        // A set of house photo links
        photo: string::String,
        // The landlord's description of the house
        description: string::String,
    }

    // present a house rental contract object
    public struct Lease has key, store {
        // uid of the Lease object
        id: UID,
        // uid of house object
        house_id: ID,
        // Tenant's account address
        tenant: address,
        // Landlord's account address
        landlord: address,
        // The month plan to rent
        tenancy: u32,
        // The amount of gas already paid
        paid_rent: u64,
        // The amount of gas already paid for deposit
        paid_deposit: u64,
    }

    // presents inspection report object
    // The landlord submits the inspection report, and the administrator reviews it
    public struct Inspection has key, store {
        // uid of the Inspection object
        id: UID,
        // id of the house object
        house_id: ID,
        // id of the lease object
        lease_id: ID,
        // Damage level, from 0 to 3, evaluated by the landlord
        damage: u8,
        // Description of damage details submitted by the landlord
        damage_description: string::String,
        // Photos of the damaged area submitted by the landlord
        damage_photo: string::String,
        // Damage level evaluated by administrator
        damage_assessment_ret: u8,
        // Deducting the deposit based on the damage to the house
        deduct_deposit: u64,
        // Used to mark whether the administrator reviewed it or not
        review_status: u8,
    }

    //
    // -------------------- Initializers --------------------
    //
    /// Create a platform (call once, keep it shared or transfer to an owner account).
    public entry fun init_platform(owner: address, ctx: &mut TxContext) {
        let platform = RentalPlatform {
            id: object::new(ctx),
            deposit_pool: table::new<ID, u64>(ctx),
            balance: balance::zero<SUI>(),
            notices: table::new<ID, RentalNotice>(ctx),
            owner,
        };
        transfer::public_share_object(platform);
    }

    /// Mint an Admin object (only platform owner can mint if you pass a reference to the platform).
    public entry fun mint_admin(platform: &RentalPlatform, ctx: &mut TxContext) {
        assert!(platform.owner == tx_context::sender(ctx), ENoPermission);
        let admin = Admin { id: object::new(ctx) };
        transfer::public_share_object(admin);
    }

    //
    // -------------------- Core Flows --------------------
    //
    // The landlord releases a rental message, creates a RentalNotice object and a House object
    public entry fun post_rental_notice(
        platform: &mut RentalPlatform,
        monthly_rent: u64,
        housing_area: u64,
        description: vector<u8>,
        photo: vector<u8>,
        ctx: &mut TxContext
    ) {
        let house = post_rental_notice_internal(platform, monthly_rent, housing_area, description, photo, ctx);
        // Landlord keeps custody of the House object and can later transfer to tenant on success.
        transfer::transfer(house, tx_context::sender(ctx));
    }

    public fun post_rental_notice_internal(
        platform: &mut RentalPlatform,
        monthly_rent: u64,
        housing_area: u64,
        description: vector<u8>,
        photo: vector<u8>,
        ctx: &mut TxContext
    ): House {
        // calculate deposit by monthly_rent
        let deposit = (monthly_rent * DEPOSIT_PERCENT) / 100;

        let house = House {
            id: object::new(ctx),
            area: housing_area,
            owner: tx_context::sender(ctx),
            photo: string::utf8(photo),
            description: string::utf8(description),
        };
        let rentalnotice = RentalNotice {
            id: object::new(ctx),
            deposit,
            monthly_rent,
            house_id: object::uid_to_inner(&house.id),
            landlord: tx_context::sender(ctx),
        };

        table::add<ID, RentalNotice>(&mut platform.notices, object::uid_to_inner(&house.id), rentalnotice);

        house
    }

    // call pay_rent function, transfer rent coin object to landlord, deposit will be managed by platform.
    public entry fun pay_rent_and_transfer(
        platform: &mut RentalPlatform,
        house_address: address,
        tenancy: u32,
        paid: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let house_id: ID = object::id_from_address(house_address);
        let (rent_coin, deposit_coin, landlord) = pay_rent(platform, house_id, tenancy, paid, ctx);
        transfer::public_transfer(rent_coin, landlord);
        balance::join(&mut platform.balance, coin::into_balance(deposit_coin));
    }

    // Tenants pay rent and sign rental contracts
    public fun pay_rent(
        platform: &mut RentalPlatform,
        house_id: ID,
        tenancy: u32,
        paid: Coin<SUI>,
        ctx: &mut TxContext
    ): (Coin<SUI>, Coin<SUI>, address) {
        assert!(tenancy > 0, ETenancyIncorrect);
        assert!(table::contains<ID, RentalNotice>(&platform.notices, house_id), EInvalidNotice);

        let notice = table::borrow<ID, RentalNotice>(&platform.notices, house_id);
        // Ensure no existing deposit held for this house (prevents double-book)
        assert!(!table::contains<ID, u64>(&platform.deposit_pool, notice.house_id), EInvalidHouse);

        let rent = notice.monthly_rent * (tenancy as u64);
        let total_fee = rent + notice.deposit;
        assert!(total_fee == coin::value(&paid), EInvalidSuiAmount);

        // split out the deposit (kept by platform)
        // NOTE: this assumes coin::split(&mut Coin<T>, amount, &mut TxContext) API.
        // If your SDK uses coin::split(&mut Coin<T>, amount) without ctx, remove `ctx`.
        let mut paid_mut = paid;
        let deposit_coin = coin::split<SUI>(&mut paid_mut, notice.deposit, ctx);
        table::add<ID, u64>(&mut platform.deposit_pool, notice.house_id, notice.deposit);

        // lease is an immutable (frozen) object
        let lease = Lease {
            id: object::new(ctx),
            tenant: tx_context::sender(ctx),
            landlord: notice.landlord,
            tenancy,
            paid_rent: rent,
            paid_deposit: notice.deposit,
            house_id: notice.house_id,
        };
        transfer::public_freeze_object(lease);

        // remove notice from platform (no longer available)
        let RentalNotice { id: notice_id, monthly_rent: _, deposit: _, house_id: _, landlord } =
            table::remove<ID, RentalNotice>(&mut platform.notices, house_id);
        object::delete(notice_id);

        (paid_mut, deposit_coin, landlord)
    }

    // After the tenant pays the rent, the landlord transfers the house to the tenant
    public entry fun transfer_house_to_tenant(lease: &Lease, house: House) {
        transfer::transfer(house, lease.tenant)
    }

    // Rent expires, landlord inspects and submits inspection report
    public entry fun landlord_inspect(
        lease: &Lease,
        damage: u8,
        damage_description: vector<u8>,
        damage_photo: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(lease.landlord == tx_context::sender(ctx), ENoPermission);
        assert!(damage >= DAMAGE_LEVEL_0 && damage <= DAMAGE_LEVEL_3, EDamageIncorrect);
        let inspection = Inspection {
            id: object::new(ctx),
            house_id: lease.house_id,
            lease_id: object::uid_to_inner(&lease.id),
            damage,
            damage_description: string::utf8(damage_description),
            damage_photo: string::utf8(damage_photo),
            damage_assessment_ret: DAMAGE_LEVEL_UNKNOWN,
            deduct_deposit: 0,
            review_status: WAITING_FOR_REVIEW,
        };

        transfer::public_share_object(inspection);
    }

    // The platform administrator reviews the inspection report and deducts the deposit as compensation for the landlord
    public entry fun review_inspection_report(
        platform: &mut RentalPlatform,
        lease: &Lease,
        inspection: &mut Inspection,
        _admin: &Admin,
        damage: u8,
        ctx: &mut TxContext
    ) {
        // optional: enforce only platform.owner can review by checking sender == platform.owner
        // assert!(platform.owner == tx_context::sender(ctx), ENoPermission);

        assert!(lease.house_id == inspection.house_id, EWrongParams);
        assert!(inspection.review_status == WAITING_FOR_REVIEW, EInspectionReviewed);
        assert!(table::contains<ID, u64>(&platform.deposit_pool, lease.house_id), EInvalidDeposit);

        let deduct_deposit: u64 = calculate_deduct_deposit(lease.paid_deposit, damage);
        let deposit_amount = table::borrow_mut<ID, u64>(&mut platform.deposit_pool, lease.house_id);

        // platform must actually hold enough pooled balance to honor deduction
        assert!(deduct_deposit <= balance::value<SUI>(&platform.balance), EInsufficientBalance);

        inspection.damage_assessment_ret = damage;
        inspection.review_status = REVIEWED;
        inspection.deduct_deposit = deduct_deposit;

        if (deduct_deposit > 0) {
            *deposit_amount = *deposit_amount - deduct_deposit;

            let deduct_coin = coin::take<SUI>(&mut platform.balance, deduct_deposit, ctx);
            transfer_deposit(deduct_coin, lease.landlord)
        };
    }

    // The tenant returns the room to the landlord, collects deposit
    public entry fun tenant_return_house_and_transfer(
        platform: &mut RentalPlatform,
        lease: &Lease,
        house: House,
        ctx: &mut TxContext
    ) {
        let house_back = tenant_return_house(platform, lease, house, ctx);
        transfer::transfer(house_back, lease.landlord)
    }

    // The tenant returns the room to the landlord and receives the (remaining) deposit
    public fun tenant_return_house(
        platform: &mut RentalPlatform,
        lease: &Lease,
        house: House,
        ctx: &mut TxContext
    ): House {
        assert!(lease.house_id == object::uid_to_inner(&house.id), EWrongParams);
        assert!(lease.tenant == tx_context::sender(ctx), ENoPermission);
        assert!(table::contains<ID, u64>(&platform.deposit_pool, lease.house_id), EInvalidDeposit);

        let deposit_ref = table::borrow(&platform.deposit_pool, lease.house_id);
        let remaining: u64 = *deposit_ref;
        assert!(remaining <= balance::value<SUI>(&platform.balance), EInsufficientBalance);

        // If there is still any remaining deposit, refund it to the tenant
        if (remaining > 0) {
            let deposit_coin = coin::take<SUI>(&mut platform.balance, remaining, ctx);
            transfer_deposit(deposit_coin, tx_context::sender(ctx));
        };

        let _ = table::remove<ID, u64>(&mut platform.deposit_pool, lease.house_id);

        house
    }

    //
    // -------------------- Helpers --------------------
    //
    /// Simple schedule: 0 -> 0%, 1 -> 25%, 2 -> 50%, 3 -> 100% of deposit.
    /// Adjust to fit your policy.
    fun calculate_deduct_deposit(paid_deposit: u64, damage: u8): u64 {
        if (damage == DAMAGE_LEVEL_0) {
            0
        } else if (damage == DAMAGE_LEVEL_1) {
            (paid_deposit / 4)
        } else if (damage == DAMAGE_LEVEL_2) {
            (paid_deposit / 2)
        } else if (damage == DAMAGE_LEVEL_3) {
            paid_deposit
        } else {
            0
        }
    }

    fun transfer_deposit(coin: Coin<SUI>, recipient: address) {
        transfer::public_transfer(coin, recipient)
    }

    //
    /// Allow the landlord to cancel a notice before it is taken (no lease yet).
    public entry fun cancel_notice(platform: &mut RentalPlatform, house_id: ID) {
        let notice = table::borrow<ID, RentalNotice>(&platform.notices, house_id);
        assert!(notice.landlord == tx_context::sender(&mut tx_context::new() ), ENoPermission);
        let RentalNotice { id, monthly_rent: _, deposit: _, house_id: _, landlord: _ } =
            table::remove<ID, RentalNotice>(&mut platform.notices, house_id);
        object::delete(id);
    }

    /// (Debug) View how much deposit is recorded for a house id (0 if none).
    public fun deposit_recorded(platform: &RentalPlatform, house_id: ID): u64 {
        if (table::contains<ID, u64>(&platform.deposit_pool, house_id)) {
            *table::borrow<ID, u64>(&platform.deposit_pool, house_id)
        } else {
            0
        }
    }
}
