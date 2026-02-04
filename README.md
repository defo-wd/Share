
Hello Akamai Support Team,

We are currently reviewing our access control design in Linode/Akamai Cloud after the recent IAM changes that separate **Account Access** and **Entity Access**.

During this review, we identified a few points where clarification on the product roadmap would be very helpful for us to make the correct long-term design decisions.

### 1. Group-based access control (Group policies)

At present, access permissions appear to be managed on a per-user basis, and we could not find functionality equivalent to group-based role assignment (similar to IAM groups in other cloud providers).

* Are there any plans to introduce **group-based permission management** (e.g., assigning roles to a group instead of individual users)?
* If so, is there an approximate timeline or phase in which this feature is expected?

### 2. Migration status of non-natively IAM-enabled services

We understand that some services (for example, **StackScripts**) are currently treated as non-native with respect to the new IAM model.

* Which services are still considered **non-natively IAM-enabled**?
* Is there a roadmap or estimated timeframe for completing the migration of these services to the native IAM model?

### 3. Stability of the current IAM model

From an operational perspective, we would like to understand whether the current IAM implementation should be considered:

* a stable, long-term model, or
* an interim state that is expected to change significantly as migration progresses.

This information is important for us to decide whether to fully enforce fine-grained permissions now, or to apply a more relaxed, temporary model until IAM migration is complete.

Thank you in advance for your support.
We appreciate any guidance or documentation you can share regarding the IAM roadmap.

Best regards,
Shun Matsuoka
