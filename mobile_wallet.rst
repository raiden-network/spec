Raiden Mobile Wallet Specification
##################################

Overview
========

Specification document for a Raiden Network Mobile Wallet implementation.

Goal
====

Build an easy to use wallet where (in general) the user does not need to worry about how sending and receiving payments is done.

Terminology
===========

- RW = Raiden Mobile Wallet
- TS = Transport Service
- MS = Monitoring Service
- PFS = Path Finding Service
- RLC = Raiden Light Client

Requirements
============

- secure: keeps private keys safe, only in the user’s custody
- good connection with 3rd party services - MS, PFS, hubs
- easy enough onboarding
- easy to use for your mom

Depends on
==========

- specs for MS
- specs for PFS
- specs for RLC
- onboarding new users (now in PFS)

High Level Features
===================

- support both off-chain (RN) and on-chain payments (sending and receiving)
- iOS, Android; depending on tech & tooling -> +/- web & desktop
- language: English (internationalization?)
- support main net + test nets (Ropsten, Kovan, Rinkeby) + custom test net
- support official/popular token standards: ERC20, ERC223 / 777
- atomic token swap transactions (through Raiden API)
- request payments via SMS, Email, Whatsapp or Whisper (Shh) maybe with prepared data (like an order) -> receiver should click on the link and the wallet should already display the transaction and ask the user to sign it.
- notifications for
   - successful on-chain transaction (wait for confirmations)
   - incoming on-chain transactions (normal on-chain payments, channel-related activity)
   - off-chain payments (payment received, successful payment sent)
- hub reputation system
- user encrypted chat? (Signal protocol, Whisper, Matrix etc.)
- adding new/custom tokens to interact with ? - this is easy for on-chain, but for off-chain it would mean deploying a new TokenNetwork contract (will not probably be supported)

Platforms & Languages
=====================

(TODO: pros & cons for each)

Native vs. Progressive Apps
---------------------------

Progressive Apps
^^^^^^^^^^^^^^^^

- service workers handle push notifications easier
- good cache mechanism for offline / low connectivity - IndexedDB (event based, other wrapper libs exist), Cache API (Promise based)
- smaller effort for app development and maintenance

Native
^^^^^^

- more efficient, compile to wasm

Languages
---------

RLC
^^^
- https://pybee.org/ - "native" apps with Python
- compile RN code Python -> JS https://www.transcrypt.org/, https://github.com/QQuick/Transcrypt
- Python -> asm.js: http://pypyjs.org/  (step2 - asm.js -> wasm might not support everything needed for the initial py implementation)
- Python -> wasm (WIP): https://github.com/almarklein/wasmfun
- C/C++ or Rust -> wasm
- TypeScript


Other wallets
-------------

- React Native + Redux (Trustlines)
- Cordova, Ionic (LETH)
- Android native (Walleth)
- iOS + Android native (Trust Wallet)


Components
==========

Raiden Light Client Library
---------------------------

- reusable
- non-mediating transfers
- IoT compatible
- can connect to hubs (Raiden Full Nodes) for off-chain & channel-related on-chain transactions
- can connect to a PFS
- can connect to a MS
- has APIs for the same TS used by RN
- uses the same types of messages as the Raiden Full Node (except those for mediating transfers)
- (possible) also communicates with the Relay Server for (at least) push notifications for off-chain payments / channel-related events.

Raiden Full Node
----------------

- either ran by BB or chosen from the network based on predefined logic / random (handled by the PFS)

On-Chain Client Library
-----------------------

- for normal on-chain transactions logic (except channel-related)
- wallet library (keystore, account management)
- communicates with the Relay Server

Relay Server
------------

- will talk with an Ethereum Node for normal on-chain transaction needs (web3, RPC)
- push notifications server

Ethereum Node
-------------

- provides read & write access to the blockchain

MobileApp
=========

Visuals
-------

https://www.ethereum.org/images/logos/Ethereum_Visual_Identity_1.0.0.pdf

User Onboarding Flow Example
----------------------------

- install the app
- sign Terms of Use
- import wallet / generate new wallet
   - if importing a new wallet, off-chain data has to be retrieved (open channels, last balance proofs; maybe automatically add the channel 2nd parties to the address book)
- fund wallet with ETH (should be easy to copy/paste address or share)
- fund wallet with RDN / have an easy way to buy RDN from the app (agreement with an exchange or VendingMachine)
- choose automatically or show list of trustworthy hubs that have connections with the 3rd party services (settlement, path finding) or hubs that provide 3rd party services
   - prompt the user to choose one -> this means he has to put some tokens into escrow and pay some ETH, so he might not want to do that right away unless the hub is a goodwill hub and provides some funds himself (how?)
- if the user does have any channels open, he cannot make any transactions yet; a notification can be shown that he has not completed this step (e.g. action todo list)
- show a list of tokens that RN has in the registry -> show relevant tokens (high liquidity) + a search input
- prompt the user to choose token networks (he can join even without having any tokens in his wallet, because he can just receive tokens - tbd)
- when joining the token networks, the tokens should also be added for the on-chain transactions (seamless, user should not know the difference between on-chain / off-chain ; Raiden Network token registry should have an api for the token abis & addresses)
- user can deposit tokens to his wallet (easy way to copy/paste/share the address)
- prompt user to add contacts (address book) or share his address with others (link with an api that adds the address to the address book - will need the user approval in the app)

Transaction Flow Example
------------------------

- choose contact from address book or paste and address one time
- use default on-chain/off-chain setting, but show the option in the transaction page with possibility to change it.
- if off-chain -> check if there is a path to the contact / big enough capacity / or if he is connected to a hub -> if not, ask the user if he wants to open a channel
   - note - a hub might open channels himself, depending on his terms of service
   - yes -> open a channel, do the tx
   - no -> he can choose to do it on-chain

UI Features Example
-------------------

About
^^^^^

- version
- Terms of Use
- License

Settings
^^^^^^^^

- adding / removing custom token for on-chain transactions (address, name, token symbol, decimals)
- choosing between off-chain (default) and on-chain; this change can also be done in the payment flow if needed (e.g. no available channels, one time payment etc.)
- choosing currency to show along ETH / token values (BTC / USD / EUR / custom (via Kraken/other API)

Account
^^^^^^^

- wallet = 1 Ethereum address
- no registration or sign up; private keys remain with the user
- backup & restore wallet from seed words (BIP39 Mnemonic code)
- backup & restore wallet from private key / JSON file
- generate new wallet
   - pick account identicon
   - show seed words / recovery phrase
   - force user to select / write seed words
- download state logs per account (list transactions)
- share checksummed address via QRcode, SMS, Email, Whatsapp, Whisper (should be easy to use the shared address from inside the app)
- address book - custom address names & identicons
- User Authentication
   - uPort?
   - passcode, custom passphrase
   - iOS:
      - Touch ID for storing data securely using Secure Enclave chip
      - PIN code
      - FACE ID

Setup
^^^^^

- (probably not, but just mentioning it:) support for on-chain transactions targeting custom contracts (contract address, abi, assign name & identicon ; remove contract, UI for contract interface, notifications about contract events?)
- (possible) default token for paying 3rd party services / transaction gas

Channel info
^^^^^^^^^^^^

- top up the channel
- close the channel & settle
- channel history - open, top ups, payments

On-chain transaction UI
^^^^^^^^^^^^^^^^^^^^^^^

- input: receiver address, ETH / tokens value, data (bytes), gas limit, gas price
- show: Max Transaction Fee, Max Total, Fiat equivalent in chosen currency

Off-chain transaction UI
^^^^^^^^^^^^^^^^^^^^^^^^

- input: receiver, token type, amount of tokens, payment metadata for the receiver (ex. shopping cart items, order number etc)
- show: tbd

Hub reputation system (tbd)
^^^^^^^^^^^^^^^^^^^^^^^^^^^

- 3rd party services chosen automatically by reputation vs. manually by the user (or both)
- have a rating system for good hubs - count only the good feedback
- feedback can be from:
   - initial reputation deposit in the Raiden Network
   - other hubs with which the hub can gossip
   - users
- feedback can be acquired:
   - automatic metrics: response time after sending a request (have a time threshold over which the hub is awarded points), threshold for path length for PFS (shorter, the better)
   - manual rating system - users / other hubs can rate the hub

Protocols
=========

Easy onboarding
---------------

- https://github.com/ethereum/EIPs/issues/865#issuecomment-362920866 pay with tokens for gas

Payment Requests
----------------
- https://github.com/ethereum/EIPs/pull/681 - Payment request URL specification for QR codes, hyperlinks and Android Intents. (the way to go)
- https://github.com/ethereum/EIPs/pull/831 - Extracting the container format from EIP681
- https://github.com/ethereum/EIPs/issues/67 - Standard URI scheme with metadata, value and byte code (IBAN) (outdated)
- https://github.com/ethereum/wiki/wiki/ICAP:-Inter-exchange-Client-Address-Protocol

Push Notifications
------------------

- webrtc, websockets
- https://medium.com/uport/adventures-in-decentralized-push-notifications-3c64e700ec18 , https://github.com/uport-project
- https://github.com/walleth/walleth-push - Service that watches one ethereum-node via RPC and triggers FCM pushes when registered addresses have new transactions; uses https://firebase.google.com/docs/cloud-messaging  (iOS, Android, JavaScript)
- https://github.com/status-im/status-go/wiki/Whisper-Push-Notifications
- polling (LETH)

Other
-----

- https://github.com/ethereum/go-ethereum/wiki/Mobile:-Account-management
- https://github.com/ethereum/go-ethereum/wiki/Mobile%3A-Introduction
- https://github.com/ethereum/EIPs/blob/master/EIPS/eip-55.md - address checksums

Existing Tools/Services
-----------------------

Wallet
^^^^^^

- https://github.com/ConsenSys/eth-lightwallet  - Lightweight JS Wallet for Node and the browser
- https://github.com/petejkim/wallet.ts  - Utilities for cryptocurrency wallets, written in TypeScript
- https://github.com/TrustWallet/trust-keystore

Wallet SC
^^^^^^^^^

- https://github.com/gnosis/MultiSigWallet (old one)
- https://github.com/gnosis/gnosis-safe-contracts (new)

Account identity
^^^^^^^^^^^^^^^^

- https://www.uport.me/
- https://github.com/ethereum/blockies

Event Watching
^^^^^^^^^^^^^^

- https://infura.io/
- https://etherscan.io/apis#logs
- Eth.Events

Roadmap
=======

- Finalize feature specs (5 PD)
- Finalize protocols and standards research (+ competition research) (5 PD)
- Align with Raiden Network after core,MS,PFS specs are somewhat finalized (4 PD)
- Plan milestones (4 PD)
- Prototype (to test chosen frameworks - native vs. progressive apps etc.) (7 PD)
- Prototype 2 - standard wallet implementation (10 PD)
- Prototype 3 - add off-chain logic (15PD)
- MVP - off-chain + on-chain (15 PD)

Issues to clarify on
====================

- 3rd party APIs
- onboarding
- seamlessly switch from off-chain to on-chain and when (no hub available etc.)
- see overlap with uRaiden and make a first usable version for it if possible (not sacrificing the architecture - which should be made with RN in mind)
- build a micropayments-only wallet first? (advantages: lowers complexity for IoT support)

Other wallets:
==============

- https://www.cipherbrowser.com/ (iOS, Android), https://github.com/petejkim/cipher-ethereum -   ETH, ERC20 tokens; dapp browser, FACE ID, support for main net and test nets
- https://github.com/inzhoop-co/LETH (cross-platform)
   - ETH, ERC20 tokens
   - Set host node address private/test/public
   - List your transactions
   - Share Address via SMS, Email or Whisper v5 (Shh)
   - Share your geolocation
   - Request payments via SMS, Email or Whisper (Shh)
   - Send messages / images to friends and community using Whisper protocol in unpersisted chat
   - Send private unpersisted crypted messages to friends
   - Backup / Restore wallet using Mnemonic passphrase
   - Protect access with TouchID / PIN code
   - Currency convertion value via Kraken API
   - Add Custom Token and Share it with friends
   - Run DAppLeth (Decentralized external dapps embedded at runtime)
- https://github.com/walleth (Android)
- https://www.toshi.org/ (iOS, Android)
- https://github.com/status-im (iOS, Android)
- https://github.com/TrustWallet (iOS, Android)
- https://github.com/manuelsc/Lunary-Ethereum-Wallet (Android)
   - uses Etherscan API for notifications - https://github.com/manuelsc/Lunary-Ethereum-Wallet/blob/3553765fb1a1cd7a9d6cae3badbdd66ab00b7061/app/src/main/java/rehanced/com/simpleetherwallet/services/TransactionService.java
   - ETH & tokens
   - Multi wallet support
   - Support for Watch only wallets
   - Notification on incoming transactions
   - Combined transaction history
   - Addressbook and address naming
   - Importing / Exporting wallets
   - Display amounts and token in ETH, USD or BTC
   - No registration or sign up required
   - Price history charts
   - Fingerprint / Password protection
   - ERC-67 and ICAP Support
   - Adjustable gas price with minimum at 0.1 up to 32 gwei
   - Supporting 8 Currencies: USD, EUR, GBP, CHF, AUD, CAD, JPY, RUB
   - Available in English, German, Spanish, Portuguese and Hungarian
- https://token.im/ (iOS, Android) ; https://github.com/consenlabs
- https://jaxx.io  (iOS, Android, OSX, Linux, Windows, Web) - multiple currencies
- https://freewallet.org/currency/eth (iOS, Android)
- https://www.blockwallet.eu/  ; https://github.com/cybertim/blockwallet
   - Signs transactions on the device itself
   - Sends signed transactions through SSL to a secured RPC Geth server
   - SSL Server Certificate Fingerprint check implemented to warn about MITM Proxys (compromised networks)
   - AES Encryption on Private Key with custom Passcode, only decoded when needed
   - All Data stored in AES128 Encrypted container Stanford Javascript Crypto Library
   - Uses BIP39 Mnemonic code for Recovery of Private Keys
   - Implemented EIP55 capitals-based checksum on send addresses
   - Using QR Codes and Scanner with checksum to prevent typo errors
- https://eidoo.io/  (iOS, Android) - BTC, ETH, ERC20, atomic swap transactions, ICO manager
- https://wallet.mycelium.com/ (iOS, Android) - BTC wallet
- https://vynos.tech/ (in-browser, OFF-CHAIN)
- https://github.com/ethereum/mist (OSX, Linux, Windows)
- https://www.myetherwallet.com/ (web)
- https://www.exodus.io/ (OSX, Linux, Windows)
- https://electrum.org/#home (lightning) (Android, OSX, Linux, Windows)
- https://github.com/LN-Zap (lightning) (OSX, Linux, Windows)
