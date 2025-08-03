# 🎨 Proof-of-Creation Timestamp for Writers/Artists

A decentralized solution for creators to timestamp and protect their intellectual property using blockchain technology.

## 🌟 Features

- ✍️ Register creative works with immutable timestamps
- 🔐 Store IPFS hashes of content securely on-chain
- 🔍 Verify creation timestamps
- 📚 Track creator portfolios
- 🔄 Transfer ownership of registered works

## 📋 Usage

### Registering a Creation

```clarity
(contract-call? .proof-of-creation-timestamp register-creation 
    "QmXESRwGFZVZJqWPGzAMnZxYP6B1bZwC1pr5pGEYGsqhD4" 
    "My Artwork Title" 
    "digital-art")
```

### Verifying a Timestamp

```clarity
(contract-call? .proof-of-creation-timestamp verify-timestamp u1 u54321)
```

### Viewing Creator Works

```clarity
(contract-call? .proof-of-creation-timestamp get-creator-works tx-sender)
```

## 🔧 Technical Details

The contract maintains:
- Unique IDs for each creation
- IPFS hash storage
- Creation timestamps
- Ownership records
- Creator portfolios

## 🚀 Getting Started

1. Deploy the contract to your Stacks network
2. Upload your work to IPFS
3. Register the IPFS hash using the contract
4. Store your creation ID for future reference

## 💡 Use Cases

- Proving original authorship
- Copyright disputes
- Portfolio building
- Intellectual property protection
```

