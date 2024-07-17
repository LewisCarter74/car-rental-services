module car_rental::Services {
    use std::string::{Self, String};
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin;
    use sui::event;
    use sui::table::{Self, Table};
    use sui::sui::SUI;

    // Constants for the rental contract
    const ENotOwner: u64 = 1; // Error code for not being the owner
    const EInvalidWithdrawalAmount: u64 = 2; // Error code for invalid withdrawal amount
    const ECarExpired: u64 = 3; // Error code for car expired
    const ECarNotExpired: u64 = 4; // Error code for car not expired
    const EInvalidCarId: u64 = 5; // Error code for invalid car ID
    const EInvalidPrice: u64 = 6; // Error code for invalid price
    const EInsufficientPayment: u64 = 7; // Error code for insufficient payment
    const ECarIsNotListed: u64 = 8; // Error code for car not listed
    const DEPOSIT: u64 = 5000000000; // Deposit required for renting a car (500 SUI)

    // Struct representing the rental service
    public struct CarRental has key {
        id: UID, // Unique ID for the rental service
        owner_cap: ID, // Owner capability ID
        balance: Balance<SUI>, // Balance of the rental service
        deposit: Balance<SUI>, // Deposit balance for rented cars
        cars: Table<u64, ListedCar>, // Table of listed cars
        car_count: u64, // Count of listed cars
        car_added_count: u64, // Total count of cars added
    }

    // Struct representing the capability of the car owner
    public struct CarOwnerCapability has key {
        id: UID, // Unique ID for the owner capability
        rental: ID, // Associated rental ID
    }

    // Struct representing a car being rented
    public struct Car has key {
        id: UID, // Unique ID for the car
        car_index: u64, // Index of the car in the rental service
        title: String, // Title of the car
        description: String, // Description of the car
        price: u64, // Price per day for renting the car
        expiry: u64, // Expiry timestamp for the rental period
        category: u8, // Category of the car
        renter: address, // Address of the renter
    }

    // Struct representing a listed car
    public struct ListedCar has store, drop {
        index: u64, // Index of the car
        title: String, // Title of the car
        description: String, // Description of the car
        price: u64, // Price per day for renting the car
        listed: bool, // Whether the car is listed for rent
        category: u8, // Category of the car
    }

    // Event struct when a car is added
    public struct CarAdded has copy, drop {
        rental_id: ID, // ID of the rental service
        car_index: u64, // Index of the added car
    }

    // Event struct when a car is rented
    public struct CarRented has copy, drop {
        rental_id: ID, // ID of the rental service
        car_index: u64, // Index of the rented car
        days: u64, // Number of days the car is rented for
        renter: address, // Address of the renter
    }

    // Event struct when a car is returned
    public struct CarReturned has copy, drop {
        rental_id: ID, // ID of the rental service
        car_index: u64, // Index of the returned car
        return_timestamp: u64, // Timestamp when the car is returned
        renter: address, // Address of the renter
    }

    // Event struct when a car is expired
    public struct CarExpired has copy, drop {
        rental_id: ID, // ID of the rental service
        car_index: u64, // Index of the expired car
        renter: address, // Address of the renter
    }

    // Event struct when a car is unlisted
    public struct CarUnlisted has copy, drop {
        rental_id: ID, // ID of the rental service
        car_index: u64, // Index of the unlisted car
    }

    // Event struct when a withdrawal is made
    public struct RentalWithdrawal has copy, drop {
        rental_id: ID, // ID of the rental service
        amount: u64, // Amount withdrawn
        recipient: address, // Address of the recipient
    }

    // Function to create a new rental service
    public fun create_rental(recipient: address, ctx: &mut TxContext) {
        let id = object::new(ctx);
        let rental_id = object::uid_to_inner(&id);
        transfer::share_object(CarRental {
            id,
            owner_cap: rental_id,
            balance: balance::zero(),
            deposit: balance::zero(),
            cars: table::new<u64, ListedCar>(ctx),
            car_count: 0,
            car_added_count: 0,
        });
        let car_owner_cap = CarOwnerCapability {
            id: object::new(ctx),
            rental: rental_id,
        };
        transfer::transfer(car_owner_cap, recipient);
    }

    // Function to add a new car to the rental service
    public fun add_car(
        rental: &mut CarRental,
        owner_cap: &CarOwnerCapability,
        title: vector<u8>,
        description: vector<u8>,
        price: u64,
        category: u8,
        _ctx: &mut TxContext
    ) {
        let rental_id = sui::object::uid_to_inner(&rental.id);
        assert_owner(owner_cap.rental, rental_id);
        assert_price_more_than_0(price);
        let index = rental.car_added_count;
        let car = ListedCar {
            index,
            title: string::utf8(title),
            description: string::utf8(description),
            price,
            listed: true,
            category,
        };
        table::add(&mut rental.cars, index, car);
        rental.car_added_count = rental.car_added_count + 1;
        event::emit(CarAdded {
            rental_id,
            car_index: index,
        });
        rental.car_count = rental.car_count + 1;
    }

    // Function to unlist a car from the rental service
    public fun unlist_car(
        rental: &mut CarRental,
        owner_cap: &CarOwnerCapability,
        car_index: u64
    ) {
        let rental_id = sui::object::uid_to_inner(&rental.id);
        assert_owner(owner_cap.rental, rental_id);
        assert_car_index_valid(car_index, &rental.cars);
        let car = table::borrow_mut(&mut rental.cars, car_index);
        car.listed = false;
        rental.car_count = rental.car_count - 1;
        event::emit(CarUnlisted {
            rental_id,
            car_index,
        });
    }

    // Function to rent a car
    public fun rent_car(
        rental: &mut CarRental,
        car_index: u64,
        days: u64,
        recipient: address,
        payment_coin: coin::Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert_car_index_valid(car_index, &rental.cars);
        let rental_id = sui::object::uid_to_inner(&rental.id);
        let car = table::borrow_mut(&mut rental.cars, car_index);
        assert_car_listed(car.listed);
        let total_price = car.price * days + DEPOSIT;
        assert_correct_payment(coin::value(&payment_coin), total_price);
        let mut coin_balance = coin::into_balance(payment_coin);
        let paid_fee = balance::split(&mut coin_balance, car.price * days);
        balance::join(&mut rental.balance, paid_fee);
        balance::join(&mut rental.deposit, coin_balance);
        let id = sui::object::new(ctx);
        let rented_car = Car {
            id,
            car_index,
            title: car.title,
            description: car.description,
            price: car.price,
            expiry: clock::timestamp_ms(clock) + days * 86400000,
            category: car.category,
            renter: recipient,
        };
        transfer::transfer(rented_car, recipient);
        car.listed = false;
        event::emit(CarRented {
            rental_id,
            car_index,
            days,
            renter: recipient,
        });
    }

    // Function to return a rented car
    public fun return_car(
        rental: &mut CarRental,
        car: Car,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let car_index = car.car_index;
        assert_car_index_valid(car_index, &rental.cars);
        let rental_id = sui::object::uid_to_inner(&rental.id);
        let sender = tx_context::sender(ctx);
        let return_timestamp = clock::timestamp_ms(clock);
        assert_car_not_expired(car.expiry, return_timestamp);
        burn(car, ctx);
        let listed_car = table::borrow_mut(&mut rental.cars, car_index);
        listed_car.listed = true;
        event::emit(CarReturned {
            rental_id,
            car_index,
            return_timestamp,
            renter: sender,
        });
    }

    // Function to handle an expired car
    public fun car_expired(
        rental: &mut CarRental,
        car: &Car,
        clock: &Clock,
        _: &mut TxContext
    ) {
        assert_car_index_valid(car.car_index, &rental.cars);
        let rental_id = sui::object::uid_to_inner(&rental.id);
        let return_timestamp = clock::timestamp_ms(clock);
        assert_car_expired(car.expiry, return_timestamp);
        balance::join(&mut rental.balance, balance::split(&mut rental.deposit, DEPOSIT));
        table::remove(&mut rental.cars, car.car_index);
        event::emit(CarExpired {
            rental_id,
            car_index: car.car_index,
            renter: car.renter,
        });
    }

    // Function to withdraw funds from the rental service
    public fun withdraw_from_rental(
        rental: &mut CarRental,
        owner_cap: &CarOwnerCapability,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let rental_id = sui::object::uid_to_inner(&rental.id);
        assert_owner(owner_cap.rental, rental_id);
        let balance = balance::value(&rental.balance);
        assert_valid_withdrawal_amount(amount, balance);
        let withdrawal = coin::take(&mut rental.balance, amount, ctx);
        transfer::public_transfer(withdrawal, recipient);
        event::emit(RentalWithdrawal {
            rental_id,
            amount,
            recipient,
        });
    }

    // Function to burn a car object
    public entry fun burn(nft: Car, _: &mut TxContext) {
        let Car {
            id,
            car_index: _,
            title: _,
            description: _,
            price: _,
            expiry: _,
            category: _,
            renter: _,
        } = nft;
        object::delete(id);
    }

    // Assertion function to check if the caller is the owner
    fun assert_owner(cap_id: ID, rental_id: ID) {
        assert!(cap_id == rental_id, ENotOwner);
    }

    // Assertion function to check if the price is more than 0
    fun assert_price_more_than_0(price: u64) {
        assert!(price > 0, EInvalidPrice);
    }

    // Assertion function to check if the car is listed
    fun assert_car_listed(status: bool) {
        assert!(status, ECarIsNotListed);
    }

    // Assertion function to check if the car index is valid
    fun assert_car_index_valid(car_index: u64, cars: &Table<u64, ListedCar>) {
        assert!(table::contains(cars, car_index), EInvalidCarId);
    }

    // Assertion function to check if the payment is correct
    fun assert_correct_payment(payment: u64, price: u64) {
        assert!(payment == price, EInsufficientPayment);
    }

    // Assertion function to check if the withdrawal amount is valid
    fun assert_valid_withdrawal_amount(amount: u64, balance: u64) {
        assert!(amount <= balance, EInvalidWithdrawalAmount);
    }

    // Assertion function to check if the car is not expired
    fun assert_car_not_expired(expiry: u64, return_timestamp: u64) {
        assert!(return_timestamp < expiry, ECarExpired);
    }

    // Assertion function to check if the car is expired
    fun assert_car_expired(expiry: u64, return_timestamp: u64) {
        assert!(return_timestamp > expiry, ECarNotExpired);
    }
}
