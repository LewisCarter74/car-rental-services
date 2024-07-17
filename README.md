# Car Rental Services Module

This module implements a car rental service on the Sui blockchain using the Sui Move language. It provides functionality to create a rental service, add cars to the service, rent cars, return rented cars, handle expired rentals, and withdraw funds from the service.

## Table of Contents
1. [Overview](#overview)
2. [Constants](#constants)
3. [Structs](#structs)
4. [Events](#events)
5. [Functions](#functions)
    - [create_rental](#create_rental)
    - [add_car](#add_car)
    - [unlist_car](#unlist_car)
    - [rent_car](#rent_car)
    - [return_car](#return_car)
    - [car_expired](#car_expired)
    - [withdraw_from_rental](#withdraw_from_rental)
    - [burn](#burn)
6. [Assertions](#assertions)
7. [Usage](#usage)

## Introduction

The `car_rental::Services` module allows users to manage a car rental business on the blockchain. It supports adding cars to the rental service, listing and unlisting cars, renting cars, and managing rental deposits and balances.

## Constants

- `ENotOwner`: Error code for not being the owner (`1`).
- `EInvalidWithdrawalAmount`: Error code for invalid withdrawal amount (`2`).
- `ECarExpired`: Error code for car expired (`3`).
- `ECarNotExpired`: Error code for car not expired (`4`).
- `EInvalidCarId`: Error code for invalid car ID (`5`).
- `EInvalidPrice`: Error code for invalid price (`6`).
- `EInsufficientPayment`: Error code for insufficient payment (`7`).
- `ECarIsNotListed`: Error code for car not listed (`8`).
- `DEPOSIT`: Deposit required for renting a car (500 SUI).

## Structs

### CarRental
Represents the rental service.
- `id`: Unique ID for the rental service.
- `owner_cap`: Owner capability ID.
- `balance`: Balance of the rental service.
- `deposit`: Deposit balance for rented cars.
- `cars`: Table of listed cars.
- `car_count`: Count of listed cars.
- `car_added_count`: Total count of cars added.

### CarOwnerCapability
Represents the capability of the car owner.
- `id`: Unique ID for the owner capability.
- `rental`: Associated rental ID.

### Car
Represents a car being rented.
- `id`: Unique ID for the car.
- `car_index`: Index of the car in the rental service.
- `title`: Title of the car.
- `description`: Description of the car.
- `price`: Price per day for renting the car.
- `expiry`: Expiry timestamp for the rental period.
- `category`: Category of the car.
- `renter`: Address of the renter.

### ListedCar
Represents a listed car.
- `index`: Index of the car.
- `title`: Title of the car.
- `description`: Description of the car.
- `price`: Price per day for renting the car.
- `listed`: Whether the car is listed for rent.
- `category`: Category of the car.

## Events

### CarAdded
Triggered when a car is added.
- `rental_id`: ID of the rental service.
- `car_index`: Index of the added car.

### CarRented
Triggered when a car is rented.
- `rental_id`: ID of the rental service.
- `car_index`: Index of the rented car.
- `days`: Number of days the car is rented for.
- `renter`: Address of the renter.

### CarReturned
Triggered when a car is returned.
- `rental_id`: ID of the rental service.
- `car_index`: Index of the returned car.
- `return_timestamp`: Timestamp when the car is returned.
- `renter`: Address of the renter.

### CarExpired
Triggered when a car is expired.
- `rental_id`: ID of the rental service.
- `car_index`: Index of the expired car.
- `renter`: Address of the renter.

### CarUnlisted
Triggered when a car is unlisted.
- `rental_id`: ID of the rental service.
- `car_index`: Index of the unlisted car.

### RentalWithdrawal
Triggered when a withdrawal is made.
- `rental_id`: ID of the rental service.
- `amount`: Amount withdrawn.
- `recipient`: Address of the recipient.

## Functions

### create_rental
Creates a new rental service.

**Parameters:**
- `recipient`: Address of the recipient.
- `ctx`: Mutable reference to the transaction context.

### add_car
Adds a new car to the rental service.

**Parameters:**
- `rental`: Mutable reference to the CarRental struct.
- `owner_cap`: Reference to the CarOwnerCapability struct.
- `title`: Title of the car (vector of bytes).
- `description`: Description of the car (vector of bytes).
- `price`: Price per day for renting the car.
- `category`: Category of the car.
- `_ctx`: Mutable reference to the transaction context.

### unlist_car
Unlists a car from the rental service.

**Parameters:**
- `rental`: Mutable reference to the CarRental struct.
- `owner_cap`: Reference to the CarOwnerCapability struct.
- `car_index`: Index of the car to unlist.

### rent_car
Rents a car from the rental service.

**Parameters:**
- `rental`: Mutable reference to the CarRental struct.
- `car_index`: Index of the car to rent.
- `days`: Number of days to rent the car.
- `recipient`: Address of the recipient.
- `payment_coin`: Coin used for payment.
- `clock`: Reference to the Clock struct.
- `ctx`: Mutable reference to the transaction context.

### return_car
Returns a rented car to the rental service.

**Parameters:**
- `rental`: Mutable reference to the CarRental struct.
- `car`: Car struct representing the rented car.
- `clock`: Reference to the Clock struct.
- `ctx`: Mutable reference to the transaction context.

### car_expired
Handles an expired car rental.

**Parameters:**
- `rental`: Mutable reference to the CarRental struct.
- `car`: Reference to the Car struct.
- `clock`: Reference to the Clock struct.
- `ctx`: Mutable reference to the transaction context.

### withdraw_from_rental
Withdraws funds from the rental service.

**Parameters:**
- `rental`: Mutable reference to the CarRental struct.
- `owner_cap`: Reference to the CarOwnerCapability struct.
- `amount`: Amount to withdraw.
- `recipient`: Address of the recipient.
- `ctx`: Mutable reference to the transaction context.

### burn
Burns a car object.

**Parameters:**
- `nft`: Car struct representing the car to burn.
- `ctx`: Mutable reference to the transaction context.

## Assertions

### assert_owner
Asserts that the caller is the owner.

**Parameters:**
- `cap_id`: ID of the capability.
- `rental_id`: ID of the rental service.

### assert_price_more_than_0
Asserts that the price is more than 0.

**Parameters:**
- `price`: Price to check.

### assert_car_listed
Asserts that the car is listed.

**Parameters:**
- `status`: Listing status of the car.

### assert_car_index_valid
Asserts that the car index is valid.

**Parameters:**
- `car_index`: Index of the car to check.
- `cars`: Reference to the table of listed cars.

### assert_correct_payment
Asserts that the payment is correct.

**Parameters:**
- `payment`: Payment amount.
- `price`: Price to check against.

### assert_valid_withdrawal_amount
Asserts that the withdrawal amount is valid.

**Parameters:**
- `amount`: Amount to withdraw.
- `balance`: Current balance.

### assert_car_not_expired
Asserts that the car is not expired.

**Parameters:**
- `expiry`: Expiry timestamp of the car.
- `return_timestamp`: Timestamp of the return.

### assert_car_expired
Asserts that the car is expired.

**Parameters:**
- `expiry`: Expiry timestamp of the car.
- `return_timestamp`: Timestamp of the check.

## Usage

1. **Create a Rental Service:**
   ```move
   create_rental(recipient: address, ctx: &mut TxContext);
   ```

2. **Add a Car to the Rental Service:**
   ```move
   add_car(rental: &mut CarRental, owner_cap: &CarOwnerCapability, title: vector<u8>, description: vector<u8>, price: u64, category: u8, _ctx: &mut TxContext);
   ```

3. **Unlist a Car:**
   ```move
   unlist_car(rental: &mut CarRental, owner_cap: &CarOwnerCapability, car_index: u64);
   ```

4. **Rent a Car:**
   ```move
   rent_car(rental: &mut CarRental, car_index: u64, days: u64, recipient: address, payment_coin: coin::Coin<SUI>, clock: &Clock, ctx: &mut TxContext);
   ```

5. **Return a Car:**
   ```move
   return_car(rental: &mut CarRental, car: Car, clock: &Clock, ctx: &mut TxContext);
   ```

6

. **Handle an Expired Car:**
   ```move
   car_expired(rental: &mut CarRental, car: &Car, clock: &Clock, _: &mut TxContext);
   ```

7. **Withdraw Funds:**
   ```move
   withdraw_from_rental(rental: &mut CarRental, owner_cap: &CarOwnerCapability, amount: u64, recipient: address, ctx: &mut TxContext);
   ```

8. **Burn a Car Object:**
   ```move
   burn(nft: Car, _: &mut TxContext);
   ```

This module provides a comprehensive framework for managing a car rental service on the Sui blockchain, enabling car owners to list and manage their cars while providing a secure and efficient rental process for users.