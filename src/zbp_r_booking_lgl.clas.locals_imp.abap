class lhc_Booking definition inheriting from cl_abap_behavior_handler.
  private section.

    constants:
      begin of booking_status,
        new    type c length 1 value 'N', "New
        booked type c length 1 value 'B', "Booked
      end of booking_status.

    methods calculateTotalPrice for determine on modify
      importing keys for Booking~calculateTotalPrice.

    methods setBookingDate for determine on save
      importing keys for Booking~setBookingDate.

    methods setBookingNumber for determine on save
      importing keys for Booking~setBookingNumber.

    methods validateConnection for validate on save
      importing keys for Booking~validateConnection.

    methods validateCustomer for validate on save
      importing keys for Booking~validateCustomer.

endclass.

class lhc_Booking implementation.

  method setBookingNumber.
    data:
      lv_max_bookingid   type /dmo/booking_id,
      lt_bookings_update type table for update zr_travel_lgl\\Booking,
      ls_booking         type structure for read result zr_booking_lgl.

    "Read all travels for the requested bookings
    " If multiple bookings of the same travel are requested, the travel is returned only once.
    read entities of zr_travel_lgl in local mode
         entity Booking by \_Travel
         fields ( TravelUUID )
         with corresponding #( keys )
         result data(lt_travels).

    " Read all bookings for all affected travels
    read entities of zr_travel_lgl in local mode
         entity Travel by \_Booking
         fields ( BookingID )
         with corresponding #( lt_travels )
         link data(lt_booking_links)
         result data(lt_bookings).

    " Process all affected travels.
    loop at lt_travels into data(travel).

      " find max used bookingID in all bookings of this travel
      lv_max_bookingid = '0000'.
      loop at lt_booking_links into data(ls_booking_link) using key id where source-%tky = travel-%tky.
        " Short dump occurs if link table does not match read table, which must never happen
        ls_booking = lt_bookings[ key id  %tky = ls_booking_link-target-%tky ].
        if ls_booking-BookingID > lv_max_bookingid.
          lv_max_bookingid = ls_booking-BookingID.
        endif.
      endloop.

      "Provide a booking ID for all bookings of this travel that have none.
      loop at lt_booking_links into ls_booking_link using key id where source-%tky = travel-%tky.
        " Short dump occurs if link table does not match read table, which must never happen
        ls_booking = lt_bookings[ key id  %tky = ls_booking_link-target-%tky ].
        if ls_booking-BookingID is initial.
          lv_max_bookingid += 1.
          append value #( %tky      = ls_booking-%tky
                          BookingID = lv_max_bookingid
                        ) to lt_bookings_update.
        endif.
      endloop.
    endloop.

    " Provide a booking ID for all bookings that have none.
    modify entities of zr_travel_lgl in local mode
      entity booking
        update fields ( BookingID )
        with lt_bookings_update.

  endmethod.

  method setBookingDate.

    read entities of zr_travel_lgl in local mode
      entity Booking
        fields ( BookingDate )
        with corresponding #( keys )
      result data(lt_bookings).

    delete lt_bookings where BookingDate is not initial.
    check lt_bookings is not initial.

    loop at lt_bookings assigning field-symbol(<ls_booking>).
      <ls_booking>-BookingDate = cl_abap_context_info=>get_system_date( ).
    endloop.

    modify entities of zr_travel_lgl in local mode
      entity Booking
        update  fields ( BookingDate )
        with corresponding #( lt_bookings ).

  endmethod.

  method calculateTotalPrice.

    " Read all parent UUIDs
    read entities of zr_travel_lgl in local mode
      entity Booking by \_Travel
        fields ( TravelUUID  )
        with corresponding #(  keys  )
      result data(lt_travels).

    " Trigger Re-Calculation on Root Node
    modify entities of zr_travel_lgl in local mode
      entity Travel
        execute reCalcTotalPrice
          from corresponding  #( lt_travels ).

  endmethod.


  method validateCustomer.

    read entities of zr_travel_lgl in local mode
      entity Booking
        fields (  CustomerID )
        with corresponding #( keys )
    result data(lt_bookings).

    read entities of zr_travel_lgl in local mode
      entity Booking by \_Travel
        from corresponding #( lt_bookings )
      link data(travel_booking_links).

    data lt_customers type sorted table of /dmo/customer with unique key customer_id.

    " Optimization of DB select: extract distinct non-initial customer IDs
    lt_customers = corresponding #( lt_bookings discarding duplicates mapping customer_id = CustomerID except * ).
    delete lt_customers where customer_id is initial.

    if  lt_customers is not initial.
      " Check if customer ID exists
      select from /dmo/customer fields customer_id
                                for all entries in @lt_customers
                                where customer_id = @lt_customers-customer_id
      into table @data(valid_customers).
    endif.

    " Raise message for non existing customer id
    loop at lt_bookings into data(ls_booking).
      append value #(  %tky               = ls_booking-%tky
                       %state_area        = 'VALIDATE_CUSTOMER' ) to reported-booking.

      if ls_booking-CustomerID is  initial.
        append value #( %tky = ls_booking-%tky ) to failed-booking.

        append value #( %tky                = ls_booking-%tky
                        %state_area         = 'VALIDATE_CUSTOMER'
                         %msg                = new /dmo/cm_flight_messages(
                                                                textid = /dmo/cm_flight_messages=>enter_customer_id
                                                                severity = if_abap_behv_message=>severity-error )
                        %path               = value #( travel-%tky = travel_booking_links[ key id  source-%tky = ls_booking-%tky ]-target-%tky )
                        %element-CustomerID = if_abap_behv=>mk-on
                       ) to reported-booking.

      elseif ls_booking-CustomerID is not initial and not line_exists( valid_customers[ customer_id = ls_booking-CustomerID ] ).
        append value #(  %tky = ls_booking-%tky ) to failed-booking.

        append value #( %tky                = ls_booking-%tky
                        %state_area         = 'VALIDATE_CUSTOMER'
                         %msg                = new /dmo/cm_flight_messages(
                                                                textid = /dmo/cm_flight_messages=>customer_unkown
                                                                customer_id = ls_booking-customerId
                                                                severity = if_abap_behv_message=>severity-error )
                        %path               = value #( travel-%tky = travel_booking_links[ key id  source-%tky = ls_booking-%tky ]-target-%tky )
                        %element-CustomerID = if_abap_behv=>mk-on
                       ) to reported-booking.
      endif.

    endloop.

  endmethod.

  method validateConnection.

    read entities of zr_travel_lgl in local mode
      entity Booking
        fields ( BookingID AirlineID ConnectionID FlightDate )
        with corresponding #( keys )
      result data(lt_bookings).

    read entities of zr_travel_lgl in local mode
      entity Booking by \_Travel
        from corresponding #( lt_bookings )
      link data(travel_booking_links).

    loop at lt_bookings assigning field-symbol(<ls_booking>).
      "overwrite state area with empty message to avoid duplicate messages
      append value #(  %tky               = <ls_booking>-%tky
                       %state_area        = 'VALIDATE_CONNECTION' ) to reported-booking.

      " Raise message for non existing airline ID
      if <ls_booking>-AirlineID is initial.
        append value #( %tky = <ls_booking>-%tky ) to failed-booking.

        append value #( %tky                = <ls_booking>-%tky
                        %state_area         = 'VALIDATE_CONNECTION'
                         %msg                = new /dmo/cm_flight_messages(
                                                                textid = /dmo/cm_flight_messages=>enter_airline_id
                                                                severity = if_abap_behv_message=>severity-error )
                        %path              = value #( travel-%tky = travel_booking_links[ key id  source-%tky = <ls_booking>-%tky ]-target-%tky )
                        %element-AirlineID = if_abap_behv=>mk-on
                       ) to reported-booking.
      endif.
      " Raise message for non existing connection ID
      if <ls_booking>-ConnectionID is initial.
        append value #( %tky = <ls_booking>-%tky ) to failed-booking.

        append value #( %tky                = <ls_booking>-%tky
                        %state_area         = 'VALIDATE_CONNECTION'
                        %msg                = new /dmo/cm_flight_messages(
                                                                textid = /dmo/cm_flight_messages=>enter_connection_id
                                                                severity = if_abap_behv_message=>severity-error )
                        %path               = value #( travel-%tky = travel_booking_links[ key id  source-%tky = <ls_booking>-%tky ]-target-%tky )
                        %element-ConnectionID = if_abap_behv=>mk-on
                       ) to reported-booking.
      endif.
      " Raise message for non existing flight date
      if <ls_booking>-FlightDate is initial.
        append value #( %tky = <ls_booking>-%tky ) to failed-booking.

        append value #( %tky                = <ls_booking>-%tky
                        %state_area         = 'VALIDATE_CONNECTION'
                        %msg                = new /dmo/cm_flight_messages(
                                                                textid = /dmo/cm_flight_messages=>enter_flight_date
                                                                severity = if_abap_behv_message=>severity-error )
                        %path               = value #( travel-%tky = travel_booking_links[ key id  source-%tky = <ls_booking>-%tky ]-target-%tky )
                        %element-FlightDate = if_abap_behv=>mk-on
                       ) to reported-booking.
      endif.
      " check if flight connection exists
      if <ls_booking>-AirlineID is not initial and
         <ls_booking>-ConnectionID is not initial and
         <ls_booking>-FlightDate is not initial.

        select single Carrier_ID, Connection_ID, Flight_Date
               from /dmo/flight
               where carrier_id    eq @<ls_booking>-AirlineID
                 and connection_id eq @<ls_booking>-ConnectionID
                 and  flight_date  eq @<ls_booking>-FlightDate
               into @data(ls_flight).

        if sy-subrc <> 0.
          append value #( %tky = <ls_booking>-%tky ) to failed-booking.

          append value #( %tky                 = <ls_booking>-%tky
                          %state_area          = 'VALIDATE_CONNECTION'
                          %msg                 = new /dmo/cm_flight_messages(
                                                                textid      = /dmo/cm_flight_messages=>no_flight_exists
                                                                carrier_id  = <ls_booking>-AirlineID
                                                                flight_date = <ls_booking>-FlightDate
                                                                severity    = if_abap_behv_message=>severity-error )
                          %path                  = value #( travel-%tky = travel_booking_links[ key id  source-%tky = <ls_booking>-%tky ]-target-%tky )
                          %element-FlightDate    = if_abap_behv=>mk-on
                          %element-AirlineID     = if_abap_behv=>mk-on
                          %element-ConnectionID  = if_abap_behv=>mk-on
                        ) to reported-booking.

        endif.

      endif.

    endloop.

  endmethod.

endclass.
