module voting::management {
    use std::string;
    use std::signer;
    use std::vector;
    use std::table;
    use voting::validation;

    // 错误码定义
    const E_INVALID_VOTING_INFO: u64 = 2001;
    const E_UNAUTHORIZED: u64 = 2002;
    const E_VOTING_ALREADY_EXISTS: u64 = 2003;
    const E_VOTING_NOT_FOUND: u64 = 2004;
    const E_INVALID_CANDIDATE_NAME: u64 = 2005;
    const E_VOTING_ALREADY_STARTED: u64 = 2006;
    const E_VOTING_ALREADY_ENDED: u64 = 2007;

    // 投票状态枚举
    public enum VotingStatus has store, drop, copy {
        NotStarted,
        Active,
        Ended
    }

    // 投票信息结构 (unchanged)
    public struct VotingInfo has store {
        id: u64,
        title: string::String,
        description: string::String,
        start_time: u64,
        end_time: u64,
        status: VotingStatus,
        creator: address,
    }

    //
    // Registry foundation (per-admin)
    //
    // New VotingSystem resource that holds a per-admin registry of votings.
    // - next_voting_id: next id to assign
    // - votings: table::Table<u64, VotingInfo>
    //
    public struct VotingSystem has key {
        next_voting_id: u64,
        votings: table::Table<u64, VotingInfo>,
    }

    ////////////////////////////////////////////////////////////////////////////
    // Registry API
    ////////////////////////////////////////////////////////////////////////////

    /// Initialize the VotingSystem under `admin` if it does not already exist.
    /// Safe to call multiple times (no-op when the resource already exists).
    public fun init_voting_system(admin: &signer) acquires VotingSystem {
        let admin_addr = signer::address_of(admin);
        if (!exists<VotingSystem>(admin_addr)) {
            let tbl = table::new<u64, VotingInfo>();
            move_to(admin, VotingSystem {
                next_voting_id: 0,
                votings: tbl,
            });
        }
    }

    /// Register a new voting into the admin's VotingSystem.
    /// Preconditions: admin must have a VotingSystem (call `init_voting_system` first).
    /// Returns the assigned voting_id. The VotingInfo.id field is set to the assigned id.
    public fun register_voting(admin: &signer, voting_info: VotingInfo): u64 acquires VotingSystem {
        let admin_addr = signer::address_of(admin);
        // Ensure registry exists
        assert!(exists<VotingSystem>(admin_addr), E_VOTING_NOT_FOUND);

        let registry = borrow_global_mut<VotingSystem>(admin_addr);
        let assigned_id = registry.next_voting_id;

        // Set the id field on the VotingInfo being stored.
        // Reconstruct the struct with the assigned id to ensure the id field is correct.
        let stored_info = VotingInfo {
            id: assigned_id,
            title: voting_info.title,
            description: voting_info.description,
            start_time: voting_info.start_time,
            end_time: voting_info.end_time,
            status: voting_info.status,
            creator: voting_info.creator,
        };

        // Insert into the table
        table::add(&mut registry.votings, assigned_id, stored_info);

        // Increment next id
        registry.next_voting_id = assigned_id + 1;

        assigned_id
    }

    /// Immutable borrow accessor for a voting by id.
    /// Preconditions: VotingSystem must exist under `admin_addr` and the voting_id must be registered.
    public fun borrow_voting_by_id(admin_addr: address, voting_id: u64): &VotingInfo acquires VotingSystem {
        assert!(exists<VotingSystem>(admin_addr), E_VOTING_NOT_FOUND);
        let registry = borrow_global<VotingSystem>(admin_addr);
        assert!(table::contains(&registry.votings, voting_id), E_VOTING_NOT_FOUND);
        table::borrow(&registry.votings, voting_id)
    }

    /// Mutable borrow accessor for a voting by id.
    /// Preconditions: admin signer must own a VotingSystem and the voting_id must be registered.
    public fun borrow_voting_by_id_mut(admin: &signer, voting_id: u64): &mut VotingInfo acquires VotingSystem {
        let admin_addr = signer::address_of(admin);
        assert!(exists<VotingSystem>(admin_addr), E_VOTING_NOT_FOUND);
        let registry = borrow_global_mut<VotingSystem>(admin_addr);
        assert!(table::contains(&registry.votings, voting_id), E_VOTING_NOT_FOUND);
        table::borrow_mut(&mut registry.votings, voting_id)
    }

    /// Helper: check whether a voting id exists under the given admin address.
    public fun voting_exists(admin_addr: address, voting_id: u64): bool acquires VotingSystem {
        if (!exists<VotingSystem>(admin_addr)) {
            false
        } else {
            table::contains(&borrow_global<VotingSystem>(admin_addr).votings, voting_id)
        }
    }
}