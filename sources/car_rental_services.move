module car_rental::Services {
    use std::string::{Self, String};
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin;
    use sui::event;
    use sui::table::{Self, Table};
    use sui::sui::SUI;

    // Constants for the rental contract
    const ENotOwner: u64 = 1;
    const EInvalidWithdrawalAmount: u64 = 2;
    const ECarExpired: u64 = 3;
    const ECarNotExpired: u64 = 4;
    const EInvalidCarId: u64 = 5;
    const EInvalidPrice: u64 = 6;
    const EInsufficientPayment: u64 = 7;
    const ECarIsNotListed: u64 = 8;
    const DEPOSIT: u64 = 5000000000; // Deposit required for renting a car (500 SUI)

    // Struct representing the rental service
    public struct CarRental has key {
        id: UID,
        owner_cap: ID,
        balance: Balance<SUI>,
        deposit: Balance<SUI>,
        cars: Table<u64, ListedCar>,
        car_count: u64,
        car_added_count: u64,
    }

    // Struct representing the capability of the car owner
    public struct CarOwnerCapability has key {
        id: UID,
        rental: ID,
    }

    // Struct representing a car being rented
    public struct Car has key {
        id: UID,
        car_index: u64,
        title: String,
        description: String,
        price: u64,
        expiry: u64,
        category: u8,
        renter: address,
        rating: u8, // New field to store the car rating
    }

    // Struct representing a listed car
    public struct ListedCar has store, drop {
        index: u64,
        title: String,
        description: String,
        price: u64,
        listed: bool,
        category: u8,
    }

    // Event struct when a car is added
    public struct CarAdded has copy, drop {
        rental_id: ID,
        car_index: u64,
    }

    // Event struct when a car is rented
    public struct CarRented has copy, drop {
        rental_id: ID,
        car_index: u64,
        days: u64,
        renter: address,
    }

    // Event struct when a car is returned
    public struct CarReturned has copy, drop {
        rental_id: ID,
        car_index: u64,
        return_timestamp: u64,
        renter: address,
    }

    // Event struct when a car is expired
    public struct CarExpired has copy, drop {
        rental_id: ID,
        car_index: u64,
        renter: address,
    }

    // Event struct when a car is unlisted
    public struct CarUnlisted has copy, drop {
        rental_id: ID,
        car_index: u64,
    }

    // Event struct when a withdrawal is made
    public struct RentalWithdrawal has copy, drop {
        rental_id: ID,
        amount: u64,
        recipient: address,
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
            rating: 0, // Initialize rating to 0
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

    // Function to extend the rental period of a car
    public fun extend_rental(
        car: &mut Car,
        extra_days: u64,
        payment_coin: coin::Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let additional_cost = car.price * extra_days;
        assert_correct_payment(coin::value(&payment_coin), additional_cost);
        let mut coin_balance = coin::into_balance(payment_coin);
        balance::join(&mut car_rental.balance, coin_balance);
        car.expiry = car.expiry + extra_days * 86400000;
        let rental_id = sui::object::uid_to_inner(&car_rental.id);
        event::emit(CarRented {
            rental_id,
            car_index: car.car_index,
            days: extra_days,
            renter: car.renter,
        });
    }

    // Function to rate a car
    public fun rate_car(
        car: &mut Car,
        rating: u8,
    ) {
        assert!(rating >= 1 && rating <= 5, 9); // Ensuring rating is between 1 and 5
        car.rating = rating;
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
            rating: _,
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
