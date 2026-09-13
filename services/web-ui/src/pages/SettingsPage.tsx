import { Fragment, useEffect, useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import clsx from "clsx";
import { Plus } from "lucide-react";
import {
  createTenant,
  getTenant,
  getTenants,
  updateTenant,
} from "../api/tenants";
import { createUser, getUsers, updateUser } from "../api/users";
import {
  createBrokerAccount,
  deleteBrokerAccount,
  getBrokerAccounts,
  updateBrokerAccount,
} from "../api/broker-accounts";
import { getAuditEvents } from "../api/audit";
import { useAuthStore } from "../stores/auth";
import type { BrokerAccountResponse, UserResponse } from "../types";
import { Badge } from "../components/ui/Badge";
import { Button } from "../components/ui/Button";
import { Card } from "../components/ui/Card";
import { EmptyState } from "../components/ui/EmptyState";
import { Input } from "../components/ui/Input";
import { Modal } from "../components/ui/Modal";
import { Select } from "../components/ui/Select";
import { Spinner } from "../components/ui/Spinner";
import {
  Table,
  TableBody,
  TableCell,
  TableEmpty,
  TableHead,
  TableHeader,
  TableRow,
} from "../components/ui/Table";

type BadgeVariant = "success" | "warning" | "danger" | "info" | "neutral";
type Tab = "tenant" | "users" | "broker-accounts" | "audit-log";

const tabs: { id: Tab; label: string }[] = [
  { id: "tenant", label: "Tenant" },
  { id: "users", label: "Users" },
  { id: "broker-accounts", label: "Broker Accounts" },
  { id: "audit-log", label: "Audit Log" },
];

const USER_ROLES = [
  "TENANT_ADMIN",
  "TRADER",
  "RESEARCHER",
  "RISK_MANAGER",
  "VIEWER",
];

const brokerStatusVariant: Record<string, BadgeVariant> = {
  ACTIVE: "success",
  INACTIVE: "neutral",
  ERROR: "danger",
};

function jsonBlock(data: unknown) {
  return (
    <pre className="text-xs text-slate-400 bg-surface-2 rounded p-2 overflow-x-auto">
      {JSON.stringify(data, null, 2)}
    </pre>
  );
}

export default function SettingsPage() {
  const queryClient = useQueryClient();
  const tenantId = useAuthStore((state) => state.tenantId);
  const role = useAuthStore((state) => state.role);

  const isPlatformAdmin = role === "PLATFORM_ADMIN";
  const isTenantAdmin = role === "TENANT_ADMIN";

  const [tab, setTab] = useState<Tab>("tenant");

  // --- Tenant tab state ---
  const [createTenantModalOpen, setCreateTenantModalOpen] = useState(false);
  const [newTenantName, setNewTenantName] = useState("");
  const [newTenantCurrency, setNewTenantCurrency] = useState("INR");
  const [newTenantPlan, setNewTenantPlan] = useState("starter");

  const [editTenantName, setEditTenantName] = useState("");
  const [editTenantPlan, setEditTenantPlan] = useState("");
  const [editTenantCurrency, setEditTenantCurrency] = useState("");

  // --- Users tab state ---
  const [addUserModalOpen, setAddUserModalOpen] = useState(false);
  const [newUserEmail, setNewUserEmail] = useState("");
  const [newUserPassword, setNewUserPassword] = useState("");
  const [newUserRole, setNewUserRole] = useState("VIEWER");
  const [newUserPasswordError, setNewUserPasswordError] = useState<
    string | null
  >(null);

  const [editingUser, setEditingUser] = useState<UserResponse | null>(null);
  const [editUserRole, setEditUserRole] = useState("VIEWER");
  const [editUserActive, setEditUserActive] = useState(true);

  // --- Broker accounts tab state ---
  const [addAccountModalOpen, setAddAccountModalOpen] = useState(false);
  const [newAccountBrokerType, setNewAccountBrokerType] = useState("ZERODHA");
  const [newAccountDisplayName, setNewAccountDisplayName] = useState("");
  const [newAccountIsPrimary, setNewAccountIsPrimary] = useState(false);

  const [editingAccount, setEditingAccount] =
    useState<BrokerAccountResponse | null>(null);
  const [editAccountDisplayName, setEditAccountDisplayName] = useState("");
  const [editAccountIsPrimary, setEditAccountIsPrimary] = useState(false);

  const [deletingAccount, setDeletingAccount] =
    useState<BrokerAccountResponse | null>(null);

  // --- Audit log tab state ---
  const [expandedAuditId, setExpandedAuditId] = useState<string | null>(null);

  // --- Queries ---
  const tenantQuery = useQuery({
    queryKey: ["tenant", tenantId],
    queryFn: () => getTenant(tenantId as string),
    enabled: tenantId !== null,
  });

  const tenantsQuery = useQuery({
    queryKey: ["tenants"],
    queryFn: () => getTenants(),
    enabled: tenantId === null && isPlatformAdmin,
  });

  const usersQuery = useQuery({
    queryKey: ["users", tenantId],
    queryFn: () => getUsers(tenantId as string),
    enabled: tenantId !== null,
  });

  const brokerAccountsQuery = useQuery({
    queryKey: ["broker-accounts", tenantId],
    queryFn: () => getBrokerAccounts(tenantId as string),
    enabled: tenantId !== null,
  });

  const auditQuery = useQuery({
    queryKey: ["audit", tenantId],
    queryFn: () => getAuditEvents(tenantId as string),
    enabled: tenantId !== null,
  });

  // Keep the tenant edit form in sync with the latest fetched tenant.
  useEffect(() => {
    if (tenantQuery.data) {
      setEditTenantName(tenantQuery.data.name);
      setEditTenantPlan(tenantQuery.data.subscription_plan);
      setEditTenantCurrency(tenantQuery.data.default_currency);
    }
  }, [tenantQuery.data]);

  // --- Mutations ---
  const createTenantMutation = useMutation({
    mutationFn: () =>
      createTenant({
        name: newTenantName.trim(),
        default_currency: newTenantCurrency.trim() || undefined,
        subscription_plan: newTenantPlan.trim() || undefined,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["tenants"] });
      setCreateTenantModalOpen(false);
      setNewTenantName("");
      setNewTenantCurrency("INR");
      setNewTenantPlan("starter");
    },
  });

  const updateTenantMutation = useMutation({
    mutationFn: () =>
      updateTenant(tenantId as string, {
        name: editTenantName.trim(),
        subscription_plan: editTenantPlan.trim(),
        default_currency: editTenantCurrency.trim(),
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["tenant", tenantId] });
    },
  });

  const createUserMutation = useMutation({
    mutationFn: () =>
      createUser(tenantId as string, {
        email: newUserEmail.trim(),
        password: newUserPassword,
        role: newUserRole,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["users", tenantId] });
      setAddUserModalOpen(false);
      setNewUserEmail("");
      setNewUserPassword("");
      setNewUserRole("VIEWER");
      setNewUserPasswordError(null);
    },
  });

  const updateUserMutation = useMutation({
    mutationFn: () =>
      updateUser(tenantId as string, (editingUser as UserResponse).id, {
        role: editUserRole,
        is_active: editUserActive,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["users", tenantId] });
      setEditingUser(null);
    },
  });

  const createAccountMutation = useMutation({
    mutationFn: () =>
      createBrokerAccount(tenantId as string, {
        broker_type: newAccountBrokerType,
        display_name: newAccountDisplayName.trim(),
        is_primary: newAccountIsPrimary,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["broker-accounts", tenantId],
      });
      setAddAccountModalOpen(false);
      setNewAccountBrokerType("ZERODHA");
      setNewAccountDisplayName("");
      setNewAccountIsPrimary(false);
    },
  });

  const updateAccountMutation = useMutation({
    mutationFn: () =>
      updateBrokerAccount(
        tenantId as string,
        (editingAccount as BrokerAccountResponse).id,
        {
          display_name: editAccountDisplayName.trim(),
          is_primary: editAccountIsPrimary,
        },
      ),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["broker-accounts", tenantId],
      });
      setEditingAccount(null);
    },
  });

  const deleteAccountMutation = useMutation({
    mutationFn: () =>
      deleteBrokerAccount(
        tenantId as string,
        (deletingAccount as BrokerAccountResponse).id,
      ),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["broker-accounts", tenantId],
      });
      setDeletingAccount(null);
    },
  });

  // --- Handlers ---
  function handleCreateTenant(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    createTenantMutation.mutate();
  }

  function handleUpdateTenant(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    updateTenantMutation.mutate();
  }

  function handleCreateUser(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (newUserPassword.length < 8) {
      setNewUserPasswordError("Password must be at least 8 characters");
      return;
    }
    setNewUserPasswordError(null);
    createUserMutation.mutate();
  }

  function openEditUser(user: UserResponse) {
    setEditingUser(user);
    setEditUserRole(user.role);
    setEditUserActive(user.is_active);
  }

  function handleUpdateUser(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    updateUserMutation.mutate();
  }

  function handleCreateAccount(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    createAccountMutation.mutate();
  }

  function openEditAccount(account: BrokerAccountResponse) {
    setEditingAccount(account);
    setEditAccountDisplayName(account.display_name);
    setEditAccountIsPrimary(account.is_primary);
  }

  function handleUpdateAccount(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    updateAccountMutation.mutate();
  }

  const tenant = tenantQuery.data;
  const tenants = tenantsQuery.data ?? [];
  const users = usersQuery.data ?? [];
  const brokerAccounts = brokerAccountsQuery.data ?? [];
  const auditEvents = [...(auditQuery.data ?? [])].sort(
    (a, b) =>
      new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-slate-50">Settings</h1>
          <p className="mt-1 text-sm text-slate-400">
            Manage tenant, users, broker accounts, and the audit log
          </p>
        </div>
        {tab === "tenant" && isPlatformAdmin && tenantId === null && (
          <Button onClick={() => setCreateTenantModalOpen(true)}>
            <Plus className="size-4" />
            Create Tenant
          </Button>
        )}
        {tab === "users" && tenantId !== null && (
          <Button onClick={() => setAddUserModalOpen(true)}>
            <Plus className="size-4" />
            Add User
          </Button>
        )}
        {tab === "broker-accounts" && tenantId !== null && (
          <Button onClick={() => setAddAccountModalOpen(true)}>
            <Plus className="size-4" />
            Add Account
          </Button>
        )}
      </div>

      <div className="flex gap-1">
        {tabs.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => setTab(item.id)}
            className={clsx(
              "rounded-md px-4 py-2 text-sm font-medium transition-colors",
              tab === item.id
                ? "bg-surface-2 text-brand-400"
                : "text-slate-400 hover:bg-surface-2 hover:text-slate-50",
            )}
          >
            {item.label}
          </button>
        ))}
      </div>

      {tab === "tenant" &&
        (tenantId !== null ? (
          tenantQuery.isPending ? (
            <div className="flex justify-center py-24 text-brand-400">
              <Spinner size="lg" />
            </div>
          ) : tenantQuery.isError ? (
            <Card>
              <p className="text-sm text-loss">
                Failed to load tenant: {tenantQuery.error.message}
              </p>
            </Card>
          ) : (
            <div className="space-y-6">
              <Card header="Tenant Details">
                <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                  <div>
                    <p className="text-xs uppercase tracking-wider text-slate-400">
                      Name
                    </p>
                    <p className="mt-1 text-sm text-slate-50">{tenant?.name}</p>
                  </div>
                  <div>
                    <p className="text-xs uppercase tracking-wider text-slate-400">
                      Status
                    </p>
                    <Badge
                      className="mt-1"
                      variant={
                        tenant?.status === "ACTIVE" ? "success" : "danger"
                      }
                    >
                      {tenant?.status}
                    </Badge>
                  </div>
                  <div>
                    <p className="text-xs uppercase tracking-wider text-slate-400">
                      Subscription Plan
                    </p>
                    <p className="mt-1 text-sm text-slate-50">
                      {tenant?.subscription_plan}
                    </p>
                  </div>
                  <div>
                    <p className="text-xs uppercase tracking-wider text-slate-400">
                      Default Currency
                    </p>
                    <p className="mt-1 text-sm text-slate-50">
                      {tenant?.default_currency}
                    </p>
                  </div>
                </div>
              </Card>

              {isTenantAdmin && (
                <Card header="Edit Tenant">
                  <form onSubmit={handleUpdateTenant} className="space-y-4">
                    <Input
                      label="Name"
                      required
                      value={editTenantName}
                      onChange={(event) =>
                        setEditTenantName(event.target.value)
                      }
                    />
                    <Input
                      label="Subscription Plan"
                      required
                      value={editTenantPlan}
                      onChange={(event) =>
                        setEditTenantPlan(event.target.value)
                      }
                    />
                    <Input
                      label="Default Currency"
                      required
                      value={editTenantCurrency}
                      onChange={(event) =>
                        setEditTenantCurrency(event.target.value)
                      }
                    />
                    {updateTenantMutation.isError && (
                      <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
                        {updateTenantMutation.error.message}
                      </p>
                    )}
                    <Button
                      type="submit"
                      loading={updateTenantMutation.isPending}
                    >
                      Save Changes
                    </Button>
                  </form>
                </Card>
              )}
            </div>
          )
        ) : isPlatformAdmin ? (
          tenantsQuery.isPending ? (
            <div className="flex justify-center py-24 text-brand-400">
              <Spinner size="lg" />
            </div>
          ) : tenantsQuery.isError ? (
            <Card>
              <p className="text-sm text-loss">
                Failed to load tenants: {tenantsQuery.error.message}
              </p>
            </Card>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Subscription Plan</TableHead>
                  <TableHead>Default Currency</TableHead>
                  <TableHead>Created</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {tenants.length === 0 ? (
                  <TableEmpty
                    colSpan={5}
                    message="No tenants yet. Create one to get started."
                  />
                ) : (
                  tenants.map((item) => (
                    <TableRow key={item.id}>
                      <TableCell className="font-medium">{item.name}</TableCell>
                      <TableCell>
                        <Badge
                          variant={
                            item.status === "ACTIVE" ? "success" : "danger"
                          }
                        >
                          {item.status}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-slate-400">
                        {item.subscription_plan}
                      </TableCell>
                      <TableCell className="text-slate-400">
                        {item.default_currency}
                      </TableCell>
                      <TableCell className="text-slate-400">
                        {format(new Date(item.created_at), "MMM d, yyyy HH:mm")}
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          )
        ) : (
          <Card>
            <EmptyState
              title="No tenant selected"
              description="You are signed in without a tenant. Contact a platform admin for access."
            />
          </Card>
        ))}

      {tab === "users" &&
        (tenantId === null ? (
          <Card>
            <EmptyState
              title="No tenant selected"
              description="Select or create a tenant before managing users."
            />
          </Card>
        ) : usersQuery.isPending ? (
          <div className="flex justify-center py-24 text-brand-400">
            <Spinner size="lg" />
          </div>
        ) : usersQuery.isError ? (
          <Card>
            <p className="text-sm text-loss">
              Failed to load users: {usersQuery.error.message}
            </p>
          </Card>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Email</TableHead>
                <TableHead>Role</TableHead>
                <TableHead>Active</TableHead>
                <TableHead>Created</TableHead>
                <TableHead className="w-20" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {users.length === 0 ? (
                <TableEmpty
                  colSpan={5}
                  message="No users yet. Add one to get started."
                />
              ) : (
                users.map((user) => (
                  <TableRow key={user.id}>
                    <TableCell className="font-medium">{user.email}</TableCell>
                    <TableCell>
                      <Badge variant="info">{user.role}</Badge>
                    </TableCell>
                    <TableCell>
                      <Badge variant={user.is_active ? "success" : "neutral"}>
                        {user.is_active ? "Active" : "Inactive"}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-slate-400">
                      {format(new Date(user.created_at), "MMM d, yyyy HH:mm")}
                    </TableCell>
                    <TableCell>
                      <Button
                        size="sm"
                        variant="ghost"
                        onClick={() => openEditUser(user)}
                      >
                        Edit
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        ))}

      {tab === "broker-accounts" &&
        (tenantId === null ? (
          <Card>
            <EmptyState
              title="No tenant selected"
              description="Select or create a tenant before managing broker accounts."
            />
          </Card>
        ) : brokerAccountsQuery.isPending ? (
          <div className="flex justify-center py-24 text-brand-400">
            <Spinner size="lg" />
          </div>
        ) : brokerAccountsQuery.isError ? (
          <Card>
            <p className="text-sm text-loss">
              Failed to load broker accounts:{" "}
              {brokerAccountsQuery.error.message}
            </p>
          </Card>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Display Name</TableHead>
                <TableHead>Broker Type</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Primary</TableHead>
                <TableHead>Created</TableHead>
                <TableHead className="w-32" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {brokerAccounts.length === 0 ? (
                <TableEmpty
                  colSpan={6}
                  message="No broker accounts yet. Add one to get started."
                />
              ) : (
                brokerAccounts.map((account) => (
                  <TableRow key={account.id}>
                    <TableCell className="font-medium">
                      {account.display_name}
                    </TableCell>
                    <TableCell>
                      <Badge>{account.broker_type}</Badge>
                    </TableCell>
                    <TableCell>
                      <Badge
                        variant={
                          brokerStatusVariant[account.status] ?? "neutral"
                        }
                      >
                        {account.status}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <Badge variant={account.is_primary ? "info" : "neutral"}>
                        {account.is_primary ? "Yes" : "No"}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-slate-400">
                      {format(
                        new Date(account.created_at),
                        "MMM d, yyyy HH:mm",
                      )}
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-2">
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={() => openEditAccount(account)}
                        >
                          Edit
                        </Button>
                        <Button
                          size="sm"
                          variant="ghost"
                          className="text-loss hover:text-loss"
                          onClick={() => setDeletingAccount(account)}
                        >
                          Delete
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        ))}

      {tab === "audit-log" &&
        (tenantId === null ? (
          <Card>
            <EmptyState
              title="No tenant selected"
              description="Select or create a tenant before viewing the audit log."
            />
          </Card>
        ) : auditQuery.isPending ? (
          <div className="flex justify-center py-24 text-brand-400">
            <Spinner size="lg" />
          </div>
        ) : auditQuery.isError ? (
          <Card>
            <p className="text-sm text-loss">
              Failed to load audit events: {auditQuery.error.message}
            </p>
          </Card>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Action</TableHead>
                <TableHead>Resource</TableHead>
                <TableHead>User ID</TableHead>
                <TableHead>IP Address</TableHead>
                <TableHead>Timestamp</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {auditEvents.length === 0 ? (
                <TableEmpty colSpan={5} message="No audit events yet." />
              ) : (
                auditEvents.map((event) => (
                  <Fragment key={event.id}>
                    <TableRow
                      className="cursor-pointer"
                      onClick={() =>
                        setExpandedAuditId(
                          expandedAuditId === event.id ? null : event.id,
                        )
                      }
                    >
                      <TableCell className="font-medium">
                        {event.action}
                      </TableCell>
                      <TableCell className="text-slate-400">
                        {event.resource ?? "—"}
                      </TableCell>
                      <TableCell className="text-slate-400">
                        {event.user_id
                          ? `${event.user_id.slice(0, 8)}...`
                          : "—"}
                      </TableCell>
                      <TableCell className="text-slate-400">
                        {event.ip_address ?? "—"}
                      </TableCell>
                      <TableCell className="text-slate-400">
                        {format(
                          new Date(event.created_at),
                          "MMM d, yyyy HH:mm",
                        )}
                      </TableCell>
                    </TableRow>
                    {expandedAuditId === event.id && (
                      <TableRow key={`${event.id}-expanded`}>
                        <TableCell colSpan={5} className="bg-surface-2/30">
                          <div className="space-y-3">
                            <div>
                              <p className="mb-1 text-xs font-medium uppercase tracking-wider text-slate-400">
                                Before State
                              </p>
                              {jsonBlock(event.before_state)}
                            </div>
                            <div>
                              <p className="mb-1 text-xs font-medium uppercase tracking-wider text-slate-400">
                                After State
                              </p>
                              {jsonBlock(event.after_state)}
                            </div>
                          </div>
                        </TableCell>
                      </TableRow>
                    )}
                  </Fragment>
                ))
              )}
            </TableBody>
          </Table>
        ))}

      <Modal
        open={createTenantModalOpen}
        onClose={() => setCreateTenantModalOpen(false)}
        title="Create Tenant"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setCreateTenantModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              form="create-tenant-form"
              loading={createTenantMutation.isPending}
            >
              Create
            </Button>
          </>
        }
      >
        <form
          id="create-tenant-form"
          onSubmit={handleCreateTenant}
          className="space-y-4"
        >
          <Input
            label="Name"
            required
            value={newTenantName}
            onChange={(event) => setNewTenantName(event.target.value)}
            placeholder="Acme Capital"
          />
          <Input
            label="Default Currency"
            value={newTenantCurrency}
            onChange={(event) => setNewTenantCurrency(event.target.value)}
            placeholder="INR"
          />
          <Input
            label="Subscription Plan"
            value={newTenantPlan}
            onChange={(event) => setNewTenantPlan(event.target.value)}
            placeholder="starter"
          />
          {createTenantMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {createTenantMutation.error.message}
            </p>
          )}
        </form>
      </Modal>

      <Modal
        open={addUserModalOpen}
        onClose={() => setAddUserModalOpen(false)}
        title="Add User"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setAddUserModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              form="add-user-form"
              loading={createUserMutation.isPending}
            >
              Add
            </Button>
          </>
        }
      >
        <form
          id="add-user-form"
          onSubmit={handleCreateUser}
          className="space-y-4"
        >
          <Input
            label="Email"
            type="email"
            required
            value={newUserEmail}
            onChange={(event) => setNewUserEmail(event.target.value)}
            placeholder="trader@example.com"
          />
          <Input
            label="Password"
            type="password"
            required
            minLength={8}
            value={newUserPassword}
            onChange={(event) => {
              setNewUserPassword(event.target.value);
              setNewUserPasswordError(null);
            }}
            error={newUserPasswordError ?? undefined}
            placeholder="At least 8 characters"
          />
          <Select
            label="Role"
            value={newUserRole}
            onChange={(event) => setNewUserRole(event.target.value)}
          >
            {USER_ROLES.map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </Select>
          {createUserMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {createUserMutation.error.message}
            </p>
          )}
        </form>
      </Modal>

      <Modal
        open={editingUser !== null}
        onClose={() => setEditingUser(null)}
        title="Edit User"
        footer={
          <>
            <Button variant="secondary" onClick={() => setEditingUser(null)}>
              Cancel
            </Button>
            <Button
              type="submit"
              form="edit-user-form"
              loading={updateUserMutation.isPending}
            >
              Save
            </Button>
          </>
        }
      >
        <form
          id="edit-user-form"
          onSubmit={handleUpdateUser}
          className="space-y-4"
        >
          <p className="text-sm text-slate-400">{editingUser?.email}</p>
          <Select
            label="Role"
            value={editUserRole}
            onChange={(event) => setEditUserRole(event.target.value)}
          >
            {USER_ROLES.map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </Select>
          <label className="flex items-center gap-2 text-sm text-slate-50">
            <input
              type="checkbox"
              checked={editUserActive}
              onChange={(event) => setEditUserActive(event.target.checked)}
              className="size-4 rounded border-surface-3 bg-surface-2"
            />
            Active
          </label>
          {updateUserMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {updateUserMutation.error.message}
            </p>
          )}
        </form>
      </Modal>

      <Modal
        open={addAccountModalOpen}
        onClose={() => setAddAccountModalOpen(false)}
        title="Add Broker Account"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setAddAccountModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              form="add-account-form"
              loading={createAccountMutation.isPending}
            >
              Add
            </Button>
          </>
        }
      >
        <form
          id="add-account-form"
          onSubmit={handleCreateAccount}
          className="space-y-4"
        >
          <Select
            label="Broker Type"
            value={newAccountBrokerType}
            onChange={(event) => setNewAccountBrokerType(event.target.value)}
          >
            <option value="ZERODHA">ZERODHA</option>
          </Select>
          <Input
            label="Display Name"
            required
            value={newAccountDisplayName}
            onChange={(event) => setNewAccountDisplayName(event.target.value)}
            placeholder="Zerodha - Main"
          />
          <label className="flex items-center gap-2 text-sm text-slate-50">
            <input
              type="checkbox"
              checked={newAccountIsPrimary}
              onChange={(event) => setNewAccountIsPrimary(event.target.checked)}
              className="size-4 rounded border-surface-3 bg-surface-2"
            />
            Set as primary account
          </label>
          {createAccountMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {createAccountMutation.error.message}
            </p>
          )}
        </form>
      </Modal>

      <Modal
        open={editingAccount !== null}
        onClose={() => setEditingAccount(null)}
        title="Edit Broker Account"
        footer={
          <>
            <Button variant="secondary" onClick={() => setEditingAccount(null)}>
              Cancel
            </Button>
            <Button
              type="submit"
              form="edit-account-form"
              loading={updateAccountMutation.isPending}
            >
              Save
            </Button>
          </>
        }
      >
        <form
          id="edit-account-form"
          onSubmit={handleUpdateAccount}
          className="space-y-4"
        >
          <Input
            label="Display Name"
            required
            value={editAccountDisplayName}
            onChange={(event) => setEditAccountDisplayName(event.target.value)}
          />
          <label className="flex items-center gap-2 text-sm text-slate-50">
            <input
              type="checkbox"
              checked={editAccountIsPrimary}
              onChange={(event) =>
                setEditAccountIsPrimary(event.target.checked)
              }
              className="size-4 rounded border-surface-3 bg-surface-2"
            />
            Set as primary account
          </label>
          {updateAccountMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {updateAccountMutation.error.message}
            </p>
          )}
        </form>
      </Modal>

      <Modal
        open={deletingAccount !== null}
        onClose={() => setDeletingAccount(null)}
        title="Delete Broker Account"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setDeletingAccount(null)}
            >
              Cancel
            </Button>
            <Button
              variant="danger"
              loading={deleteAccountMutation.isPending}
              onClick={() => deleteAccountMutation.mutate()}
            >
              Delete
            </Button>
          </>
        }
      >
        <p className="text-sm text-slate-400">
          Are you sure you want to delete{" "}
          <span className="font-medium text-slate-50">
            {deletingAccount?.display_name}
          </span>
          ? This action cannot be undone.
        </p>
        {deleteAccountMutation.isError && (
          <p className="mt-3 rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
            {deleteAccountMutation.error.message}
          </p>
        )}
      </Modal>
    </div>
  );
}
