# Community Learning Center Management System

A command-line app written in Dart for managing participants and learning resources (workshops, books, online courses) at a community learning center.

## Features

- Register participants with a unique ID, contact info, and status
- Add learning resources with a fee and limited slots or copies
- Process transactions with automatic discounts, payment checks, and change
- View all records or search by ID

## Requirements

- [Dart SDK](https://dart.dev/get-dart) 2.17 or later

## Run

```bash
git clone https://github.com/<your-username>/<your-repo-name>.git
cd <your-repo-name>
dart run main.dart
```

## Business Rules

- Only **Active** participants can transact.
- Every transaction gets a 10% discount, plus an extra 5% if the subtotal is PHP 1,000 or more.
- Payment must cover the total due, otherwise the transaction is cancelled.
- A resource becomes **Inactive** when its slots or copies reach 0.

## Design

`CenterRecord` is an abstract base class extended by `Participant` and `LearningResource`. The `Timestamped` and `StatusTrackable` mixins add creation time and status tracking, and a generic `find<T>()` handles typed lookups.

## Limitations

Data is stored in memory only and is lost when the program exits.
