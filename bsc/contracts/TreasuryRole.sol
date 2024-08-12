//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TreasuryRole is Initializable {
    address public ownerContract;

    struct TreasuryRoleData {
        mapping(address account => bool) hasTreasuryRole;
    }

    mapping(bytes32 role => TreasuryRoleData) treasuryRoles;

    /**
     * @dev The `account` is missing a role.
     */
    error TreasuryAccessControlUnauthorized(
        address account,
        bytes32 neededRole
    );

    event TreasuryRoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event TreasuryRoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @dev Modifier that checks that an account has a treasury role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyTreasuryRole(bytes32 _role, address _user) {
        _checkTreasuryRole(_role, _user);
        _;
    }

    function __TreasuryRoleInitializing(
        address _ownerContract
    ) internal onlyInitializing {
        ownerContract = _ownerContract;
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasTreasuryRole(
        bytes32 role,
        address account
    ) public view virtual returns (bool) {
        return treasuryRoles[role].hasTreasuryRole[account];
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {TreasuryRoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must be owner contract.
     *
     * May emit a {TreasuryRoleGranted} event.
     */
    function grantTreasuryRole(
        bytes32 _role,
        address _account,
        address _grantedBy
    ) internal {
        _grantTreasuryRole(_role, _account, _grantedBy);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {TreasuryRoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {TreasuryRoleRevoked} event.
     */
    function revokeTreasuryRole(
        bytes32 _role,
        address _account,
        address _revokedBy
    ) internal {
        _revokeTreasuryRole(_role, _account, _revokedBy);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {TreasuryRoleGranted} event.
     */
    function _grantTreasuryRole(
        bytes32 _role,
        address _account,
        address _grantedBy
    ) private returns (bool) {
        if (!hasTreasuryRole(_role, _account)) {
            treasuryRoles[_role].hasTreasuryRole[_account] = true;
            emit TreasuryRoleGranted(_role, _account, _grantedBy);
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {TreasuryRoleRevoked} event.
     */
    function _revokeTreasuryRole(
        bytes32 _role,
        address _account,
        address _revokedBy
    ) private returns (bool) {
        if (hasTreasuryRole(_role, _account)) {
            treasuryRoles[_role].hasTreasuryRole[_account] = false;
            emit TreasuryRoleRevoked(_role, _account, _revokedBy);
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Reverts with an {TreasuryAccessControlUnauthorized} error if `account`
     * is missing `role`.
     */
    function _checkTreasuryRole(bytes32 _role, address _account) private view {
        if (!hasTreasuryRole(_role, _account)) {
            revert TreasuryAccessControlUnauthorized(_account, _role);
        }
    }
}
