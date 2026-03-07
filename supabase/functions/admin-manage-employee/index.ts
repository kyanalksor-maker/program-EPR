import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Action = "create" | "update" | "deactivate" | "delete";

interface RequestBody {
  action: Action;
  employeeId?: string;
  name?: string;
  email?: string;
  password?: string;
  roleName?: string;
  permissions?: string[];
  isActive?: boolean;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    if (!supabaseUrl || !serviceRoleKey || !anonKey || !authHeader) {
      throw new Error("Missing Supabase environment configuration.");
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user: caller },
      error: callerError,
    } = await userClient.auth.getUser();

    if (callerError || !caller) {
      throw new Error("Unauthorized request.");
    }

    const { data: callerProfile, error: profileError } = await adminClient
      .from("v_users_with_permissions")
      .select("id, role_name, is_active")
      .eq("id", caller.id)
      .single();

    if (
      profileError ||
      !callerProfile ||
      !callerProfile.is_active ||
      callerProfile.role_name !== "Admin"
    ) {
      throw new Error("Only active admins can manage employees.");
    }

    const body = (await req.json()) as RequestBody;
    const permissions = body.permissions ?? [];

    switch (body.action) {
      case "create": {
        if (!body.name || !body.email || !body.password || !body.roleName) {
          throw new Error("Missing required fields for employee creation.");
        }

        const { data: role, error: roleError } = await adminClient
          .from("roles")
          .select("id")
          .eq("role_name", body.roleName)
          .single();

        if (roleError || !role) {
          throw new Error("Invalid role selected.");
        }

        const { data: created, error: createError } = await adminClient.auth.admin
          .createUser({
            email: body.email,
            password: body.password,
            email_confirm: true,
            user_metadata: { name: body.name },
          });

        if (createError || !created.user) {
          throw new Error(createError?.message ?? "Failed to create auth user.");
        }

        const employeeId = created.user.id;

        const { error: userInsertError } = await adminClient.from("users").insert({
          id: employeeId,
          name: body.name,
          email: body.email,
          role_id: role.id,
          is_active: body.isActive ?? true,
        });

        if (userInsertError) {
          throw new Error(userInsertError.message);
        }

        if (permissions.isNotEmpty) {
          const { error: permissionInsertError } = await adminClient
            .from("user_permissions")
            .insert(
              permissions.map((code) => ({
                user_id: employeeId,
                permission_code: code,
              })),
            );

          if (permissionInsertError) {
            throw new Error(permissionInsertError.message);
          }
        }

        await adminClient.rpc("write_activity_log", {
          p_actor_id: caller.id,
          p_action: "employee_created",
          p_entity_type: "user",
          p_entity_id: employeeId,
          p_metadata: {
            email: body.email,
            role_name: body.roleName,
          },
        });

        return jsonResponse({ success: true, employeeId });
      }

      case "update": {
        if (!body.employeeId || !body.name || !body.email || !body.roleName) {
          throw new Error("Missing required fields for employee update.");
        }

        const { data: role, error: roleError } = await adminClient
          .from("roles")
          .select("id")
          .eq("role_name", body.roleName)
          .single();

        if (roleError || !role) {
          throw new Error("Invalid role selected.");
        }

        const userUpdatePayload: Record<string, unknown> = {
          email: body.email,
          user_metadata: { name: body.name },
        };

        if (body.password && body.password.trim().isNotEmpty) {
          userUpdatePayload.password = body.password;
        }

        const { error: authUpdateError } = await adminClient.auth.admin.updateUserById(
          body.employeeId,
          userUpdatePayload,
        );

        if (authUpdateError) {
          throw new Error(authUpdateError.message);
        }

        const { error: profileUpdateError } = await adminClient
          .from("users")
          .update({
            name: body.name,
            email: body.email,
            role_id: role.id,
            is_active: body.isActive ?? true,
          })
          .eq("id", body.employeeId);

        if (profileUpdateError) {
          throw new Error(profileUpdateError.message);
        }

        const { error: permissionDeleteError } = await adminClient
          .from("user_permissions")
          .delete()
          .eq("user_id", body.employeeId);

        if (permissionDeleteError) {
          throw new Error(permissionDeleteError.message);
        }

        if (permissions.isNotEmpty) {
          const { error: permissionInsertError } = await adminClient
            .from("user_permissions")
            .insert(
              permissions.map((code) => ({
                user_id: body.employeeId,
                permission_code: code,
              })),
            );

          if (permissionInsertError) {
            throw new Error(permissionInsertError.message);
          }
        }

        await adminClient.rpc("write_activity_log", {
          p_actor_id: caller.id,
          p_action: "employee_updated",
          p_entity_type: "user",
          p_entity_id: body.employeeId,
          p_metadata: {
            email: body.email,
            role_name: body.roleName,
          },
        });

        return jsonResponse({ success: true, employeeId: body.employeeId });
      }

      case "deactivate": {
        if (!body.employeeId || body.isActive === undefined) {
          throw new Error("Missing employee activation payload.");
        }

        const { error } = await adminClient
          .from("users")
          .update({ is_active: body.isActive })
          .eq("id", body.employeeId);

        if (error) {
          throw new Error(error.message);
        }

        await adminClient.rpc("write_activity_log", {
          p_actor_id: caller.id,
          p_action: body.isActive ? "employee_activated" : "employee_deactivated",
          p_entity_type: "user",
          p_entity_id: body.employeeId,
          p_metadata: {},
        });

        return jsonResponse({ success: true, employeeId: body.employeeId });
      }

      case "delete": {
        if (!body.employeeId) {
          throw new Error("Missing employee identifier.");
        }

        await adminClient.rpc("write_activity_log", {
          p_actor_id: caller.id,
          p_action: "employee_deleted",
          p_entity_type: "user",
          p_entity_id: body.employeeId,
          p_metadata: {},
        });

        const { error: dbDeleteError } = await adminClient
          .from("users")
          .delete()
          .eq("id", body.employeeId);

        if (dbDeleteError) {
          throw new Error(dbDeleteError.message);
        }

        const { error: authDeleteError } = await adminClient.auth.admin.deleteUser(
          body.employeeId,
        );

        if (authDeleteError) {
          throw new Error(authDeleteError.message);
        }

        return jsonResponse({ success: true, employeeId: body.employeeId });
      }
    }
  } catch (error) {
    return jsonResponse(
      { success: false, error: error instanceof Error ? error.message : "Unknown error" },
      400,
    );
  }
});

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
