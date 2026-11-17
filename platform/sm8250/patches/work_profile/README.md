# S20 work-profile compatibility

Partial cherry-pick of MinsOS `99722b9a`, reusing its One UI 9
`UserManagerService` patch on x1q, y2q and z3q.

The legacy S20 KeyMint cannot produce the KnoxTestKeyUMS attestation chain
expected by the donor's enterprise-profile creation path. The patch skips that
attestation branch and rejoins its successful continuation. Android's managed
profile policies and separate app/data storage remain in use; this does not
enable Knox attestation or modify Secure Folder.

The module verifies that the inserted jump matches the continuation after
`AttestationUtils.deleteKey`, and fails if the donor layout changes.
Creating a work profile and provisioning Shelter still require device testing
after a future ROM build.

Upstream: https://gitlab.com/minsos1/MinsOS (GPL-3.0).
