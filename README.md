Here’s a professional, background-oriented README for your **Rental Platform Move Smart Contract** project. I’ve written it in a style suitable for GitHub or a technical report, highlighting motivation, architecture, and usage. I included both English and Chinese versions as you usually prefer.

---

# Rental Platform on Sui Move

## Background

The rental housing market often faces inefficiencies and trust issues between landlords and tenants. Common challenges include:

* **Deposit disputes**: Tenants may fear unfair deposit deductions; landlords may worry about property damage.
* **Opaque transactions**: Rent payments are often handled offline or through third-party intermediaries, reducing transparency.
* **Verification challenges**: Inspection reports and lease agreements are usually paper-based, making enforcement difficult.

To address these issues, this project implements a **decentralized rental platform on the Sui blockchain**. By leveraging Move smart contracts, the platform ensures:

* **Transparent rent and deposit management**: All transactions are on-chain, with deposits securely managed by the platform.
* **Fair dispute resolution**: Landlords submit inspection reports, and administrators can review and deduct deposits based on agreed rules.
* **Immutable lease agreements**: Lease contracts are recorded on-chain, ensuring both parties adhere to the rental terms.
* **Permissioned operations**: Only authorized parties can perform specific actions (landlords post notices, tenants pay rent, admins review inspections).

---

## Key Features

1. **Rental Notices**
   Landlords can post their house listings with rental terms, deposit requirements, and property descriptions. Each listing is represented as a `RentalNotice` object on-chain.

2. **House Objects**
   Each property is represented as a `House` object, storing essential metadata such as area, photos, description, and ownership.

3. **Lease Contracts**
   When a tenant pays rent, a `Lease` object is created, recording the rental period, paid rent, and deposit. These objects are immutable and publicly verifiable.

4. **Deposit Management**
   Deposits are securely stored in a `RentalPlatform` balance pool. The platform manages deduction and refund operations based on inspection results.

5. **Inspection & Review**
   Landlords submit `Inspection` reports after rental periods. Administrators review these reports and determine deposit deductions. The rules are transparent and encoded in the smart contract.

6. **House Transfer & Return**
   The contract manages property handover between landlord and tenant, ensuring deposits are appropriately refunded or deducted.

7. **Permissioned Roles**

   * **Platform Admins**: Review inspections, manage disputes.
   * **Landlords**: Post notices, submit inspections.
   * **Tenants**: Pay rent, return houses, receive deposit refunds.

---

## Architecture

The platform consists of the following key objects:

| Object           | Purpose                                                               |
| ---------------- | --------------------------------------------------------------------- |
| `RentalPlatform` | Main platform object holding balances, deposit pools, and notices.    |
| `Admin`          | Represents a platform administrator with inspection review authority. |
| `RentalNotice`   | Represents a rental listing posted by a landlord.                     |
| `House`          | Represents a real estate property.                                    |
| `Lease`          | Represents a rental contract between landlord and tenant.             |
| `Inspection`     | Represents a property inspection and damage report.                   |

---

## Flow Overview

1. **Landlord posts rental notice** → `RentalNotice` and `House` objects are created.
2. **Tenant pays rent and deposit** → A `Lease` object is created; deposit is stored in platform pool.
3. **Landlord transfers house** → House ownership temporarily moves to the tenant.
4. **Rental period ends** → Landlord submits inspection report.
5. **Admin reviews inspection** → Deposit deduction is processed.
6. **Tenant returns house** → Remaining deposit is refunded; house ownership returns to landlord.

---

## Benefits

* Fully **on-chain and transparent**.
* **Automated deposit handling** reduces disputes.
* **Immutable lease records** protect both landlords and tenants.
* Extensible to include **dynamic pricing, multi-tenant properties, or rental insurance**.

---

## Future Work

* Integration with off-chain oracles for property verification.
* UI/dashboard for landlords and tenants.
* Event logs for easier front-end tracking.
* Support for multi-month rental payment plans or automated reminders.

---

# 中文版 — 背景说明

## 背景

租房市场存在诸多效率和信任问题：

* **押金纠纷**：租客担心不公平扣押金，房东担心房屋损坏。
* **交易不透明**：租金支付通常离线或通过第三方，缺乏透明度。
* **合同和验收难以验证**：纸质合同和验房报告难以强制执行。

本项目在 **Sui 区块链上**实现了一个去中心化租房平台，通过 Move 智能合约保障：

* **租金与押金透明管理**：所有交易链上记录，押金由平台托管。
* **公平纠纷处理**：房东提交验房报告，管理员审核并扣除押金。
* **不可篡改租约**：租赁合同链上记录，保证双方遵守条款。
* **权限控制**：不同角色执行不同操作（房东发布，租客支付，管理员审核）。

---

## 核心功能

1. **发布租房信息**
   房东可发布带押金和房屋描述的租房信息，形成链上 `RentalNotice` 对象。

2. **房屋对象**
   每套房屋作为 `House` 对象存在，存储面积、照片、描述和所有权信息。

3. **租约合同**
   租客支付租金后创建 `Lease` 对象，记录租期、已支付租金和押金。

4. **押金管理**
   押金存储在平台余额池，平台管理扣除与退款操作。

5. **验房与审核**
   租期结束后，房东提交 `Inspection` 验房报告，管理员审核决定扣款。

6. **房屋交还**
   平台管理房屋归还与押金返还。

7. **权限角色**

   * **平台管理员**：审核验房、管理纠纷
   * **房东**：发布租房信息、提交验房
   * **租客**：支付租金、归还房屋、领取押金

---

## 流程概览

1. 房东发布租房信息 → 创建 `RentalNotice` 和 `House` 对象
2. 租客支付租金与押金 → 创建 `Lease` 对象，押金存入平台
3. 房东将房屋交给租客 → 房屋暂时转移至租客
4. 租期结束 → 房东提交验房报告
5. 管理员审核验房 → 扣除押金
6. 租客归还房屋 → 剩余押金返还，房屋归还房东

---

## 优势

* 全链上、交易透明
* 自动押金管理，减少纠纷
* 租约不可篡改，保护双方权益
* 可扩展支持动态定价、多租客或租赁保险

---

## 未来计划

* 引入链下数据源进行房屋验证
* 提供房东/租客前端面板
* 事件日志便于前端追踪
* 支持多月租金支付和自动提醒


