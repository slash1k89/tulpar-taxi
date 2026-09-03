--
-- PostgreSQL database dump
--

\restrict gfCeTAVyIcJduiGYmR2qGVEg79qOsTthIywuAhwROmvNDmr58l78iy8TpoeUtkx

-- Dumped from database version 17.11 (Debian 17.11-1.pgdg13+2)
-- Dumped by pg_dump version 17.11 (Debian 17.11-1.pgdg13+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: app_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_settings (
    id smallint DEFAULT 1 NOT NULL,
    day_minimum_fare integer DEFAULT 600 NOT NULL,
    night_minimum_fare integer DEFAULT 700 NOT NULL,
    driver_access_fee integer DEFAULT 1000 NOT NULL,
    driver_access_hours integer DEFAULT 24 NOT NULL,
    day_start_hour smallint DEFAULT 6 NOT NULL,
    night_start_hour smallint DEFAULT 22 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT app_settings_day_minimum_fare_check CHECK ((day_minimum_fare > 0)),
    CONSTRAINT app_settings_day_start_hour_check CHECK (((day_start_hour >= 0) AND (day_start_hour <= 23))),
    CONSTRAINT app_settings_driver_access_hours_check CHECK ((driver_access_hours > 0)),
    CONSTRAINT app_settings_driver_daily_fee_check CHECK ((driver_access_fee > 0)),
    CONSTRAINT app_settings_id_check CHECK ((id = 1)),
    CONSTRAINT app_settings_night_minimum_fare_check CHECK ((night_minimum_fare > 0)),
    CONSTRAINT app_settings_night_start_hour_check CHECK (((night_start_hour >= 0) AND (night_start_hour <= 23)))
);


--
-- Name: delivery_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delivery_details (
    order_id uuid NOT NULL,
    item_description text NOT NULL,
    sender_name character varying(120),
    sender_phone character varying(32),
    recipient_name character varying(120),
    recipient_phone character varying(32),
    pickup_handoff_type character varying(20) DEFAULT 'outside'::character varying NOT NULL,
    pickup_entrance character varying(30),
    pickup_apartment character varying(30),
    pickup_floor character varying(20),
    pickup_intercom character varying(50),
    pickup_comment text,
    destination_handoff_type character varying(20) DEFAULT 'outside'::character varying NOT NULL,
    destination_entrance character varying(30),
    destination_apartment character varying(30),
    destination_floor character varying(20),
    destination_intercom character varying(50),
    destination_comment text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT delivery_details_destination_handoff_type_check CHECK (((destination_handoff_type)::text = ANY ((ARRAY['door'::character varying, 'outside'::character varying])::text[]))),
    CONSTRAINT delivery_details_pickup_handoff_type_check CHECK (((pickup_handoff_type)::text = ANY ((ARRAY['door'::character varying, 'outside'::character varying])::text[])))
);


--
-- Name: driver_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.driver_profiles (
    user_id uuid NOT NULL,
    status character varying(20) DEFAULT 'draft'::character varying NOT NULL,
    car_model character varying(100),
    car_color character varying(50),
    car_number character varying(30),
    agreement_version character varying(20),
    agreement_accepted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    access_exempt boolean DEFAULT false NOT NULL,
    CONSTRAINT driver_profiles_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'pending'::character varying, 'active'::character varying, 'suspended'::character varying])::text[])))
);


--
-- Name: driver_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.driver_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    driver_id uuid NOT NULL,
    amount integer NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    valid_until timestamp with time zone NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    payment_reference character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    payment_status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    CONSTRAINT driver_subscriptions_amount_check CHECK ((amount > 0)),
    CONSTRAINT driver_subscriptions_check CHECK ((valid_until > starts_at)),
    CONSTRAINT driver_subscriptions_payment_status_check CHECK (((payment_status)::text = ANY ((ARRAY['pending'::character varying, 'paid'::character varying, 'failed'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT driver_subscriptions_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'expired'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: intercity_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.intercity_details (
    order_id uuid NOT NULL,
    departure_at timestamp with time zone NOT NULL,
    passenger_count smallint DEFAULT 1 NOT NULL,
    has_luggage boolean DEFAULT false NOT NULL,
    comment text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT intercity_details_passenger_count_check CHECK (((passenger_count >= 1) AND (passenger_count <= 20)))
);


--
-- Name: order_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    text text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: order_offers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_offers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    driver_id uuid NOT NULL,
    price integer NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT order_offers_price_check CHECK ((price > 0)),
    CONSTRAINT order_offers_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'withdrawn'::character varying])::text[])))
);


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    passenger_id uuid NOT NULL,
    driver_id uuid,
    status character varying(30) DEFAULT 'searching'::character varying NOT NULL,
    passenger_price integer NOT NULL,
    agreed_price integer,
    pickup_address text,
    destination_address text,
    pickup_lat double precision,
    pickup_lng double precision,
    destination_lat double precision,
    destination_lng double precision,
    distance_meters integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    accepted_at timestamp with time zone,
    driver_arrived_at timestamp with time zone,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    driver_lat double precision,
    driver_lng double precision,
    driver_location_updated_at timestamp with time zone,
    service_type character varying(30) DEFAULT 'city'::character varying NOT NULL,
    CONSTRAINT orders_agreed_price_check CHECK (((agreed_price IS NULL) OR (agreed_price > 0))),
    CONSTRAINT orders_distance_meters_check CHECK (((distance_meters IS NULL) OR (distance_meters >= 0))),
    CONSTRAINT orders_passenger_price_check CHECK ((passenger_price > 0)),
    CONSTRAINT orders_status_check CHECK (((status)::text = ANY ((ARRAY['searching'::character varying, 'accepted'::character varying, 'driver_arrived'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'cancelled'::character varying, 'expired'::character varying])::text[])))
);


--
-- Name: ratings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ratings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    from_user_id uuid NOT NULL,
    to_user_id uuid NOT NULL,
    score smallint NOT NULL,
    comment text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ratings_check CHECK ((from_user_id <> to_user_id)),
    CONSTRAINT ratings_score_check CHECK (((score >= 1) AND (score <= 5)))
);


--
-- Name: service_tariffs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_tariffs (
    service_type character varying(30) NOT NULL,
    minimum_day_fare integer,
    minimum_night_fare integer,
    shift_fee integer,
    shift_hours integer,
    day_start_hour smallint DEFAULT 6 NOT NULL,
    night_start_hour smallint DEFAULT 22 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT service_tariffs_day_start_hour_check CHECK (((day_start_hour >= 0) AND (day_start_hour <= 23))),
    CONSTRAINT service_tariffs_minimum_day_fare_check CHECK (((minimum_day_fare IS NULL) OR (minimum_day_fare > 0))),
    CONSTRAINT service_tariffs_minimum_night_fare_check CHECK (((minimum_night_fare IS NULL) OR (minimum_night_fare > 0))),
    CONSTRAINT service_tariffs_night_start_hour_check CHECK (((night_start_hour >= 0) AND (night_start_hour <= 23))),
    CONSTRAINT service_tariffs_shift_fee_check CHECK (((shift_fee IS NULL) OR (shift_fee > 0))),
    CONSTRAINT service_tariffs_shift_hours_check CHECK (((shift_hours IS NULL) OR (shift_hours > 0)))
);


--
-- Name: service_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_types (
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_push_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_push_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token text NOT NULL,
    platform character varying(20) DEFAULT 'android'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firebase_uid character varying(128),
    phone character varying(32),
    name character varying(120),
    rating numeric(3,2) DEFAULT 5.00 NOT NULL,
    rating_sum integer DEFAULT 0 NOT NULL,
    rating_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: app_settings app_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_settings
    ADD CONSTRAINT app_settings_pkey PRIMARY KEY (id);


--
-- Name: delivery_details delivery_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_details
    ADD CONSTRAINT delivery_details_pkey PRIMARY KEY (order_id);


--
-- Name: driver_profiles driver_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.driver_profiles
    ADD CONSTRAINT driver_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: driver_subscriptions driver_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.driver_subscriptions
    ADD CONSTRAINT driver_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: intercity_details intercity_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intercity_details
    ADD CONSTRAINT intercity_details_pkey PRIMARY KEY (order_id);


--
-- Name: order_messages order_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_messages
    ADD CONSTRAINT order_messages_pkey PRIMARY KEY (id);


--
-- Name: order_offers order_offers_order_id_driver_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_offers
    ADD CONSTRAINT order_offers_order_id_driver_id_key UNIQUE (order_id, driver_id);


--
-- Name: order_offers order_offers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_offers
    ADD CONSTRAINT order_offers_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: ratings ratings_order_id_from_user_id_to_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_order_id_from_user_id_to_user_id_key UNIQUE (order_id, from_user_id, to_user_id);


--
-- Name: ratings ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_pkey PRIMARY KEY (id);


--
-- Name: service_tariffs service_tariffs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_tariffs
    ADD CONSTRAINT service_tariffs_pkey PRIMARY KEY (service_type);


--
-- Name: service_types service_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_types
    ADD CONSTRAINT service_types_pkey PRIMARY KEY (code);


--
-- Name: user_push_tokens user_push_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_push_tokens
    ADD CONSTRAINT user_push_tokens_pkey PRIMARY KEY (id);


--
-- Name: user_push_tokens user_push_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_push_tokens
    ADD CONSTRAINT user_push_tokens_token_key UNIQUE (token);


--
-- Name: users users_firebase_uid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_firebase_uid_key UNIQUE (firebase_uid);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_driver_profiles_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_driver_profiles_status ON public.driver_profiles USING btree (status);


--
-- Name: idx_driver_subscriptions_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_driver_subscriptions_active ON public.driver_subscriptions USING btree (driver_id, valid_until DESC) WHERE ((status)::text = 'active'::text);


--
-- Name: idx_driver_subscriptions_driver; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_driver_subscriptions_driver ON public.driver_subscriptions USING btree (driver_id, valid_until DESC);


--
-- Name: idx_intercity_departure_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intercity_departure_at ON public.intercity_details USING btree (departure_at);


--
-- Name: idx_one_active_order_per_driver; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_one_active_order_per_driver ON public.orders USING btree (driver_id) WHERE ((driver_id IS NOT NULL) AND ((status)::text = ANY ((ARRAY['accepted'::character varying, 'driver_arrived'::character varying, 'in_progress'::character varying])::text[])));


--
-- Name: idx_one_active_order_per_passenger; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_one_active_order_per_passenger ON public.orders USING btree (passenger_id) WHERE ((status)::text = ANY ((ARRAY['searching'::character varying, 'accepted'::character varying, 'driver_arrived'::character varying, 'in_progress'::character varying])::text[]));


--
-- Name: idx_order_messages_order_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_messages_order_created ON public.order_messages USING btree (order_id, created_at DESC);


--
-- Name: idx_order_offers_driver; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_offers_driver ON public.order_offers USING btree (driver_id, created_at DESC);


--
-- Name: idx_order_offers_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_offers_order ON public.order_offers USING btree (order_id, created_at);


--
-- Name: idx_orders_driver_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_driver_created ON public.orders USING btree (driver_id, created_at DESC);


--
-- Name: idx_orders_passenger_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_passenger_created ON public.orders USING btree (passenger_id, created_at DESC);


--
-- Name: idx_orders_searching_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_searching_created ON public.orders USING btree (created_at DESC) WHERE ((status)::text = 'searching'::text);


--
-- Name: idx_orders_service_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_service_status_created ON public.orders USING btree (service_type, status, created_at DESC);


--
-- Name: idx_ratings_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_order ON public.ratings USING btree (order_id);


--
-- Name: idx_ratings_to_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_to_user ON public.ratings USING btree (to_user_id, created_at DESC);


--
-- Name: idx_user_push_tokens_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_push_tokens_user_id ON public.user_push_tokens USING btree (user_id);


--
-- Name: delivery_details delivery_details_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_details
    ADD CONSTRAINT delivery_details_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: driver_profiles driver_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.driver_profiles
    ADD CONSTRAINT driver_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: driver_subscriptions driver_subscriptions_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.driver_subscriptions
    ADD CONSTRAINT driver_subscriptions_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: intercity_details intercity_details_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intercity_details
    ADD CONSTRAINT intercity_details_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: order_messages order_messages_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_messages
    ADD CONSTRAINT order_messages_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: order_messages order_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_messages
    ADD CONSTRAINT order_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: order_offers order_offers_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_offers
    ADD CONSTRAINT order_offers_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: order_offers order_offers_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_offers
    ADD CONSTRAINT order_offers_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: orders orders_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: orders orders_passenger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_passenger_id_fkey FOREIGN KEY (passenger_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: orders orders_service_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_service_type_fkey FOREIGN KEY (service_type) REFERENCES public.service_types(code);


--
-- Name: ratings ratings_from_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: service_tariffs service_tariffs_service_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_tariffs
    ADD CONSTRAINT service_tariffs_service_type_fkey FOREIGN KEY (service_type) REFERENCES public.service_types(code) ON DELETE RESTRICT;


--
-- Name: user_push_tokens user_push_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_push_tokens
    ADD CONSTRAINT user_push_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict gfCeTAVyIcJduiGYmR2qGVEg79qOsTthIywuAhwROmvNDmr58l78iy8TpoeUtkx

