# Social Engagement Platform Smart Contract

A decentralized content upvoting system built on Stacks blockchain with reputation tracking, content moderation, and premium features.

## Overview

This smart contract implements a social engagement platform where users can publish content, upvote others' content, build reputation, and boost visibility through premium features. The system is designed to incentivize quality content creation through a reputation-based system while allowing for content moderation.

## Features

- **Content Management**: Publish, deactivate, and reactivate content
- **Engagement System**: Upvote content and track user interactions
- **Reputation Tracking**: Build reputation through content creation and community engagement
- **Content Highlighting**: Premium and merit-based content visibility boosting
- **Moderation Tools**: Administrative controls for platform management

## Smart Contract Details

### Data Structures

- **Content Registry**: Stores content metadata including creator, timestamps, and metrics
- **Upvote Registry**: Tracks user interactions with content
- **User Reputation Registry**: Maintains user reputation and activity metrics
- **Highlighted Content Registry**: Tracks featured or promoted content

### Core Functions

#### Content Functions
- `publish-content`: Create new content entries
- `upvote-content`: Upvote specific content
- `remove-upvote`: Remove an upvote (time-limited)
- `deactivate-content`: Remove content from active listings
- `reactivate-content`: Make content active again

#### Highlighting Functions
- `highlight-content`: Feature content (admin or high-reputation users)
- `remove-content-highlight`: Unfeature content (admin only)
- `boost-content-visibility`: Premium content promotion using STX tokens

#### Administrative Functions
- `update-platform-commission`: Modify platform fee percentage
- `update-reputation-threshold`: Change reputation requirements
- `transfer-admin-rights`: Transfer administrative control
- `initialize-platform`: Set up initial platform parameters

### Read-Only Functions

- `get-content-details`: Retrieve content metadata
- `has-user-upvoted`: Check if a user has upvoted specific content
- `get-user-reputation-data`: Get user reputation metrics
- `get-total-content-count`: Count all content items
- `is-content-highlighted`: Check if content is featured
- `get-platform-commission-rate`: Return current platform fee percentage

## Economics

- Platform takes a configurable commission (default 5%) on premium transactions
- Content creators receive STX tokens when their content is boosted
- Reputation-based incentives drive organic content quality

## Error Codes

| Code | Description |
|------|-------------|
| 1000 | Unauthorized access |
| 1001 | Already upvoted |
| 1002 | Content unavailable |
| 1003 | Self-upvote prohibited |
| 1004 | Upvote reversal prohibited |
| 1005 | Invalid parameter value |
| 1006 | Payment failed |

## Usage Examples

### Publishing Content

```clarity
;; Publish new content in the "technology" category
(contract-call? .social-engagement-platform publish-content "technology")
```

### Upvoting Content

```clarity
;; Upvote content with ID 42
(contract-call? .social-engagement-platform upvote-content u42)
```

### Boosting Content Visibility

```clarity
;; Boost content visibility with 5 STX payment
(contract-call? .social-engagement-platform boost-content-visibility u42 u5000000)
```

## Security Considerations

- Users cannot upvote their own content
- Upvote removals are time-limited (within 10 blocks)
- Administrative functions are protected
- Reputation thresholds prevent abuse of highlighting features