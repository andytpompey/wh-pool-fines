alter type public.entitlement_state add value if not exists 'pending' before 'trial';
alter type public.entitlement_state add value if not exists 'cancelled' after 'expired';
alter type public.entitlement_state add value if not exists 'refunded' after 'cancelled';
alter type public.entitlement_state add value if not exists 'complimentary' after 'refunded';
