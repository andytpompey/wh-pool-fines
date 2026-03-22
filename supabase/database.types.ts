export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  public: {
    Tables: {

      app_users: {
        Row: {
          id: string
          is_platform_admin: boolean
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          is_platform_admin?: boolean
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          is_platform_admin?: boolean
          created_at?: string
          updated_at?: string
        }
      }
      players: {
        Row: {
          id: string
          name: string
          display_name: string
          email: string
          mobile: string | null
          preferred_auth_method: 'email' | 'whatsapp'
          auth_user_id: string | null
          user_id: string | null
          receive_team_notifications: boolean
          created_at: string | null
        }
        Insert: {
          id?: string
          name: string
          display_name?: string
          email: string
          mobile?: string | null
          preferred_auth_method?: 'email' | 'whatsapp'
          auth_user_id?: string | null
          user_id?: string | null
          receive_team_notifications?: boolean
          created_at?: string | null
        }
        Update: {
          id?: string
          name?: string
          display_name?: string
          email?: string
          mobile?: string | null
          preferred_auth_method?: 'email' | 'whatsapp'
          auth_user_id?: string | null
          user_id?: string | null
          receive_team_notifications?: boolean
          created_at?: string | null
        }
      }
      teams: {
        Row: {
          id: string
          name: string
          join_code: string
          created_by: string | null
          unlock_code_hash: string | null
          unlock_code_last_rotated_at: string | null
          unlock_code_reset_required: boolean
          created_at: string
        }
        Insert: {
          id?: string
          name: string
          join_code?: string
          created_by?: string | null
          unlock_code_hash?: string | null
          unlock_code_last_rotated_at?: string | null
          unlock_code_reset_required?: boolean
          created_at?: string
        }
        Update: {
          id?: string
          name?: string
          join_code?: string
          created_by?: string | null
          unlock_code_hash?: string | null
          unlock_code_last_rotated_at?: string | null
          unlock_code_reset_required?: boolean
          created_at?: string
        }
      }
      team_memberships: {
        Row: {
          id: string
          team_id: string
          player_id: string
          role: 'captain' | 'vice_captain' | 'member'
          status: 'active' | 'invited' | 'removed'
          joined_at: string
        }
        Insert: {
          id?: string
          team_id: string
          player_id: string
          role?: 'captain' | 'vice_captain' | 'member'
          status?: 'active' | 'invited' | 'removed'
          joined_at?: string
        }
        Update: {
          id?: string
          team_id?: string
          player_id?: string
          role?: 'captain' | 'vice_captain' | 'member'
          status?: 'active' | 'invited' | 'removed'
          joined_at?: string
        }
      }
      team_invites: {
        Row: {
          id: string
          team_id: string
          email: string
          player_id: string | null
          invited_by_player_id: string | null
          status: 'pending' | 'accepted' | 'expired' | 'cancelled'
          token: string
          created_at: string
          expires_at: string | null
        }
        Insert: {
          id?: string
          team_id: string
          email: string
          player_id?: string | null
          invited_by_player_id?: string | null
          status?: 'pending' | 'accepted' | 'expired' | 'cancelled'
          token: string
          created_at?: string
          expires_at?: string | null
        }
        Update: {
          id?: string
          team_id?: string
          email?: string
          player_id?: string | null
          invited_by_player_id?: string | null
          status?: 'pending' | 'accepted' | 'expired' | 'cancelled'
          token?: string
          created_at?: string
          expires_at?: string | null
        }
      }
    }
  }
}
