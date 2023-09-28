class lhc_Travel definition inheriting from cl_abap_behavior_handler.
  private section.

    constants:
      begin of travel_status,
        open     type c length 1 value 'O', "Open
        accepted type c length 1 value 'A', "Accepted
        rejected type c length 1 value 'X', "Rejected
      end of travel_status.

    types:
      t_entities_create type table for create zr_travel_lgl\\travel,
      t_entities_update type table for update zr_travel_lgl\\travel,
      t_failed_travel   type table for failed   early zr_travel_lgl\\travel,
      t_reported_travel type table for reported early zr_travel_lgl\\travel.

    methods get_instance_features for instance features
      importing keys request requested_features for Travel result result.

    methods get_instance_authorizations for instance authorization
      importing keys request requested_authorizations for Travel result result.

    methods get_global_authorizations for global authorization
      importing request requested_authorizations for Travel result result.

    methods precheck_create for precheck
      importing entities for create Travel.

    methods precheck_update for precheck
      importing entities for update Travel.

    methods acceptTravel for modify
      importing keys for action Travel~acceptTravel result result.

    methods deductDiscount for modify
      importing keys for action Travel~deductDiscount result result.

    methods reCalcTotalPrice for modify
      importing keys for action Travel~reCalcTotalPrice.

    methods rejectTravel for modify
      importing keys for action Travel~rejectTravel result result.

    methods Resume for modify
      importing keys for action Travel~Resume.

    methods calculateTotalPrice for determine on modify
      importing keys for Travel~calculateTotalPrice.

    methods setStatusToOpen for determine on modify
      importing keys for Travel~setStatusToOpen.

    methods setTravelNumber for determine on save
      importing keys for Travel~setTravelNumber.

    methods validateAgency for validate on save
      importing keys for Travel~validateAgency.

    methods validateCustomer for validate on save
      importing keys for Travel~validateCustomer.

    methods validateDates for validate on save
      importing keys for Travel~validateDates.

    methods is_create_granted
      importing country_code          type land1 optional
      returning value(create_granted) type abap_bool.
    methods is_update_granted
      importing country_code          type land1 optional
      returning value(update_granted) type abap_bool.
    methods is_delete_granted
      importing country_code          type land1 optional
      returning value(delete_granted) type abap_bool.

    methods precheck_auth
      importing
        entities_create type t_entities_create optional
        entities_update type t_entities_update optional
      changing
        failed          type t_failed_travel
        reported        type t_reported_travel.

endclass.

class lhc_Travel implementation.

  method get_instance_features.

    read entities of zr_travel_lgl in local mode
        entity Travel
          fields ( OverallStatus )
          with corresponding #( keys )
        result data(lt_travels)
        failed failed.

    result = value #( for ls_travel in lt_travels
                          ( %tky                   = ls_travel-%tky

                            %field-BookingFee      = cond #( when ls_travel-OverallStatus = travel_status-accepted
                                                             then if_abap_behv=>fc-f-read_only
                                                             else if_abap_behv=>fc-f-unrestricted )
                            %action-acceptTravel   = cond #( when ls_travel-OverallStatus = travel_status-accepted
                                                             then if_abap_behv=>fc-o-disabled
                                                             else if_abap_behv=>fc-o-enabled )
                            %action-rejectTravel   = cond #( when ls_travel-OverallStatus = travel_status-rejected
                                                             then if_abap_behv=>fc-o-disabled
                                                             else if_abap_behv=>fc-o-enabled )
                            %action-deductDiscount = cond #( when ls_travel-OverallStatus = travel_status-accepted
                                                             then if_abap_behv=>fc-o-disabled
                                                             else if_abap_behv=>fc-o-enabled )
                            %assoc-_Booking        = cond #( when ls_travel-OverallStatus = travel_status-rejected
                                                            then if_abap_behv=>fc-o-disabled
                                                            else if_abap_behv=>fc-o-enabled )
                          ) ).

  endmethod.

  method get_instance_authorizations.

    data: lv_update_requested type abap_bool,
          lv_delete_requested type abap_bool,
          lv_update_granted   type abap_bool,
          lv_delete_granted   type abap_bool.

    read entities of zr_travel_lgl in local mode
         entity Travel
         fields ( AgencyID )
         with corresponding #( keys )
         result data(lt_travels)
         failed failed.

    check lt_travels is not initial.

    "Select country_code and agency of corresponding persistent travel instance
    "authorization  only checked against instance that have active persistence
    select from ztravel_lgl_a as travel
      inner join /dmo/agency    as agency on travel~agency_id = agency~agency_id
      fields travel~travel_uuid , travel~agency_id, agency~country_code
      for all entries in @lt_travels
      where travel_uuid eq @lt_travels-TravelUUID
      into table @data(lt_travel_agency_country).


    "edit is treated like update
    lv_update_requested = cond #( when requested_authorizations-%update      = if_abap_behv=>mk-on
                                 or requested_authorizations-%action-Edit = if_abap_behv=>mk-on
                               then abap_true else abap_false ).

    lv_delete_requested = cond #( when requested_authorizations-%delete      = if_abap_behv=>mk-on
                               then abap_true else abap_false ).


    loop at lt_travels into data(travel).
      "get country_code of agency in corresponding instance on persistent table
      read table lt_travel_agency_country with key travel_uuid = travel-TravelUUID
        assigning field-symbol(<travel_agency_country_code>).

      "Auth check for active instances that have before image on persistent table
      if sy-subrc = 0.

        "check auth for update
        if lv_update_requested = abap_true.
          lv_update_granted = is_update_granted( <travel_agency_country_code>-country_code  ).
          if lv_update_granted = abap_false.
            append value #( %tky = travel-%tky
                            %msg = new /dmo/cm_flight_messages(
                                                     textid    = /dmo/cm_flight_messages=>not_authorized_for_agencyid
                                                     agency_id = travel-AgencyID
                                                     severity  = if_abap_behv_message=>severity-error )
                            %element-AgencyID = if_abap_behv=>mk-on
                           ) to reported-travel.
          endif.
        endif.

        "check auth for delete
        if lv_delete_requested = abap_true.
          lv_delete_granted = is_delete_granted( <travel_agency_country_code>-country_code ).
          if lv_delete_granted = abap_false.
            append value #( %tky = travel-%tky
                            %msg = new /dmo/cm_flight_messages(
                                     textid   = /dmo/cm_flight_messages=>not_authorized_for_agencyid
                                     agency_id = travel-AgencyID
                                     severity = if_abap_behv_message=>severity-error )
                            %element-AgencyID = if_abap_behv=>mk-on
                           ) to reported-travel.
          endif.
        endif.

        " operations on draft instances and on active instances that have no persistent before image (eg Update on newly created instance)
        " create authorization is checked, for newly created instances
      else.
        lv_update_granted = lv_delete_granted = is_create_granted( ).
        if lv_update_granted = abap_false.
          append value #( %tky = travel-%tky
                          %msg = new /dmo/cm_flight_messages(
                                   textid   = /dmo/cm_flight_messages=>not_authorized
                                   severity = if_abap_behv_message=>severity-error )
                          %element-AgencyID = if_abap_behv=>mk-on
                        ) to reported-travel.
        endif.
      endif.

      append value #( let upd_auth = cond #( when lv_update_granted = abap_true
                                             then if_abap_behv=>auth-allowed
                                             else if_abap_behv=>auth-unauthorized )
                          del_auth = cond #( when lv_delete_granted = abap_true
                                             then if_abap_behv=>auth-allowed
                                             else if_abap_behv=>auth-unauthorized )
                      in
                       %tky = travel-%tky
                       %update                = upd_auth
                       %action-Edit           = upd_auth

                       %delete                = del_auth
                    ) to result.
    endloop.

  endmethod.

  method get_global_authorizations.

    if requested_authorizations-%create eq if_abap_behv=>mk-on.
      if is_create_granted( ) = abap_true.
        result-%create = if_abap_behv=>auth-allowed.
      else.
        result-%create = if_abap_behv=>auth-unauthorized.
        append value #( %msg    = new /dmo/cm_flight_messages(
                                       textid   = /dmo/cm_flight_messages=>not_authorized
                                       severity = if_abap_behv_message=>severity-error )
                        %global = if_abap_behv=>mk-on ) to reported-travel.

      endif.
    endif.

    "Edit is treated like update
    if requested_authorizations-%update                =  if_abap_behv=>mk-on or
       requested_authorizations-%action-Edit           =  if_abap_behv=>mk-on
.

      if  is_update_granted( ) = abap_true.
        result-%update                =  if_abap_behv=>auth-allowed.
        result-%action-Edit           =  if_abap_behv=>auth-allowed.

      else.
        result-%update                =  if_abap_behv=>auth-unauthorized.
        result-%action-Edit           =  if_abap_behv=>auth-unauthorized.

        append value #( %msg    = new /dmo/cm_flight_messages(
                                       textid   = /dmo/cm_flight_messages=>not_authorized
                                       severity = if_abap_behv_message=>severity-error )
                        %global = if_abap_behv=>mk-on )
          to reported-travel.

      endif.
    endif.


    if requested_authorizations-%delete =  if_abap_behv=>mk-on.
      if is_delete_granted( ) = abap_true.
        result-%delete = if_abap_behv=>auth-allowed.
      else.
        result-%delete = if_abap_behv=>auth-unauthorized.
        append value #( %msg    = new /dmo/cm_flight_messages(
                                       textid   = /dmo/cm_flight_messages=>not_authorized
                                       severity = if_abap_behv_message=>severity-error )
                        %global = if_abap_behv=>mk-on ) to reported-travel.
      endif.
    endif.

  endmethod.

  method precheck_create.
    precheck_auth(
      exporting
        entities_create = entities
      changing
        failed          = failed-travel
        reported        = reported-travel
    ).
  endmethod.

  method precheck_update.
    precheck_auth(
      exporting
        entities_update = entities
      changing
        failed          = failed-travel
        reported        = reported-travel
    ).
  endmethod.

  method acceptTravel.

* EML - Entity Manipulation Language
* keys[ 1 ]-
* result[ 1 ]-
* mapped
* failed-
* reported-

    "Modify travel instance
    modify entities of zr_travel_lgl in local mode
      entity Travel
        update fields (  OverallStatus )
        with value #( for key in keys ( %tky          = key-%tky
                                        OverallStatus = travel_status-accepted ) ).

    "Read changed data for action result
    read entities of zr_travel_lgl in local mode
      entity Travel
        all fields with
        corresponding #( keys )
      result data(travels).

    result = value #( for <travel> in travels ( %tky   = <travel>-%tky
                                                %param = <travel> ) ).

  endmethod.

  method rejectTravel.

    "Modify travel instance
    modify entities of zr_travel_lgl in local mode
      entity Travel
        update fields (  OverallStatus )
        with value #( for key in keys ( %tky          = key-%tky
                                        OverallStatus = travel_status-rejected ) ).

    "Read changed data for action result
    read entities of zr_travel_lgl in local mode
      entity Travel
        all fields with
        corresponding #( keys )
      result data(travels).

    result = value #( for <travel> in travels ( %tky   = <travel>-%tky
                                                %param = <travel> ) ).

  endmethod.

  method deductDiscount.

    data lt_travels_for_update type table for update zr_travel_lgl.
    data(lt_keys_with_valid_discount) = keys.

    loop at lt_keys_with_valid_discount assigning field-symbol(<key_with_valid_discount>)
           where %param-discount_percent is initial
              or %param-discount_percent > 100
              or %param-discount_percent <= 0.

      append value #( %tky = <key_with_valid_discount>-%tky ) to failed-travel.

      append value #( %tky                       = <key_with_valid_discount>-%tky
                      %msg                       = new /dmo/cm_flight_messages(
                                                       textid = /dmo/cm_flight_messages=>discount_invalid
                                                       severity = if_abap_behv_message=>severity-error )
                      %element-TotalPrice        = if_abap_behv=>mk-on
                      %op-%action-deductDiscount = if_abap_behv=>mk-on
                    ) to reported-travel.

      delete lt_keys_with_valid_discount.
    endloop.

    check lt_keys_with_valid_discount is not initial.

    "get total price
    read entities of zr_travel_lgl in local mode
      entity Travel
      fields ( BookingFee )
      with corresponding #( lt_keys_with_valid_discount )
      result data(lt_travels).

    loop at lt_travels assigning field-symbol(<travel>).
      data percentage type decfloat16.
      data(discount_percent) = lt_keys_with_valid_discount[ key id  %tky = <travel>-%tky ]-%param-discount_percent.
      percentage =  discount_percent / 100.
      data(reduced_fee) = <travel>-BookingFee * ( 1 - percentage ) .

      append value #( %tky       = <travel>-%tky
                      BookingFee = reduced_fee
                    ) to lt_travels_for_update.
    endloop.

    "update total price with reduced price
    modify entities of zr_travel_lgl in local mode
      entity Travel
       update fields ( BookingFee )
       with lt_travels_for_update.

    "Read changed data for action result
    read entities of zr_travel_lgl in local mode
      entity Travel
        all fields with
        corresponding #( lt_travels )
      result data(lt_travels_with_discount).

    result = value #( for travel in lt_travels_with_discount ( %tky   = travel-%tky
                                                               %param = travel ) ).

  endmethod.

  method reCalcTotalPrice.

    types: begin of ty_amount_per_currencycode,
             amount        type /dmo/total_price,
             currency_code type /dmo/currency_code,
           end of ty_amount_per_currencycode.

    data: lt_amounts_per_currencycode type standard table of ty_amount_per_currencycode.

    " Read all relevant travel instances.
    read entities of zr_travel_lgl in local mode
         entity Travel
            fields ( BookingFee CurrencyCode )
            with corresponding #( keys )
         result data(lt_travels).

    delete lt_travels where CurrencyCode is initial.

    " Read all associated bookings and add them to the total price.
    read entities of zr_travel_lgl in local mode
      entity Travel by \_Booking
        fields ( FlightPrice CurrencyCode )
      with corresponding #( lt_travels )
      link data(lt_booking_links)
      result data(lt_bookings).

    loop at lt_travels assigning field-symbol(<travel>).
      " Set the start for the calculation by adding the booking fee.
      lt_amounts_per_currencycode = value #( ( amount        = <travel>-bookingfee
                                               currency_code = <travel>-currencycode ) ).

      loop at lt_booking_links into data(booking_link) using key id where source-%tky = <travel>-%tky.
        " Short dump occurs if link table does not match read table, which must never happen
        data(booking) = lt_bookings[ key id  %tky = booking_link-target-%tky ].
        collect value ty_amount_per_currencycode( amount        = booking-flightprice
                                                  currency_code = booking-currencycode ) into lt_amounts_per_currencycode.

      endloop.

      delete lt_amounts_per_currencycode where currency_code is initial.

      clear <travel>-TotalPrice.
      loop at lt_amounts_per_currencycode into data(ls_amount_per_currencycode).
        " If needed do a Currency Conversion
        if ls_amount_per_currencycode-currency_code = <travel>-CurrencyCode.
          <travel>-TotalPrice += ls_amount_per_currencycode-amount.
        else.
          /dmo/cl_flight_amdp=>convert_currency(
            exporting
              iv_amount               = ls_amount_per_currencycode-amount
              iv_currency_code_source = ls_amount_per_currencycode-currency_code
              iv_currency_code_target = <travel>-CurrencyCode
              iv_exchange_rate_date   = cl_abap_context_info=>get_system_date( )
            importing
              ev_amount               = data(lv_total_book_price_per_curr)
          ).
          <travel>-TotalPrice += lv_total_book_price_per_curr.
        endif.
      endloop.
    endloop.

    " write back the modified total_price of travels
    modify entities of zr_travel_lgl in local mode
      entity travel
        update fields ( TotalPrice )
        with corresponding #( lt_travels ).

  endmethod.

  method Resume.
    data: lt_entities_update type t_entities_update.

    read entities of zr_travel_lgl in local mode
      entity Travel
        fields ( AgencyID )
        with value #(
                      for key in keys
                        %is_draft = if_abap_behv=>mk-on
                        ( %key = key-%key )
                    )
        result data(lt_travels).

    " Set %control-AgencyID (if set) to true, so that the precheck_auth checks the permissions.
    lt_entities_update = corresponding #( lt_travels changing control ).

    if lt_entities_update is not initial.
      precheck_auth(
        exporting
          entities_update = lt_entities_update
        changing
          failed          = failed-travel
          reported        = reported-travel
      ).
    endif.

  endmethod.

  method calculateTotalPrice.

    modify entities of zr_travel_lgl in local mode
           entity Travel
           execute reCalcTotalPrice
           from corresponding #( keys ).

  endmethod.

  method setStatusToOpen.

    read entities of zr_travel_lgl in local mode
         entity Travel
         fields ( OverallStatus )
         with corresponding #( keys )
         result data(lt_travels).

    "If Status is already set, do nothing
    delete lt_travels where OverallStatus is not initial.
    check lt_travels is not initial.

    modify entities of zr_travel_lgl in local mode
      entity Travel
        update fields ( OverallStatus )
        with value #( for <travel> in lt_travels ( %tky  = <travel>-%tky
                                           OverallStatus = travel_status-open ) ).

  endmethod.

  method setTravelNumber.

    read entities of zr_travel_lgl in local mode
          entity Travel
          fields ( TravelID )
          with corresponding #( keys )
          result data(lt_travels).

    delete lt_travels where TravelID is not initial.

    check lt_travels is not initial.

    "Get max travelID
    select single from ztravel_lgl_a
           fields max( travel_id )
           into @data(max_travelid).

    "update involved instances
    modify entities of zr_travel_lgl in local mode
      entity Travel
        update fields ( TravelID )
        with value #( for travel in lt_travels index into i (
                           %tky      = travel-%tky
                           TravelID  = max_travelid + i ) ).

  endmethod.

  method validateAgency.

    data: lv_modification_granted type abap_boolean,
          lv_agency_country_code  type land1.

    read entities of zr_travel_lgl in local mode
         entity Travel
         fields ( AgencyID TravelID )
         with corresponding #( keys )
         result data(lt_travels).

    data lt_agencies type sorted table of /dmo/agency with unique key agency_id.

    " Optimization of DB select: extract distinct non-initial agency IDs
    lt_agencies = corresponding #( lt_travels discarding duplicates mapping agency_id = AgencyID except * ).
    delete lt_agencies where agency_id is initial.

    if  lt_agencies is not initial.
      " Check if Agency ID exists
      select from /dmo/agency fields agency_id, country_code
                              for all entries in @lt_agencies
                              where agency_id = @lt_agencies-agency_id
        into table @data(valid_agencies).
    endif.

    " Raise message for non existing Agency id
    loop at lt_travels into data(ls_travel).
      append value #(  %tky               = ls_travel-%tky
                       %state_area        = 'VALIDATE_AGENCY'
                    ) to reported-travel.

      if ls_travel-AgencyID is initial.
        append value #( %tky = ls_travel-%tky ) to failed-travel.

        append value #( %tky                = ls_travel-%tky
                        %state_area         = 'VALIDATE_AGENCY'
                        %msg                = new /dmo/cm_flight_messages(
                                                          textid   = /dmo/cm_flight_messages=>enter_agency_id
                                                          severity = if_abap_behv_message=>severity-error )
                        %element-AgencyID   = if_abap_behv=>mk-on
                       ) to reported-travel.

      elseif ls_travel-AgencyID is not initial and not line_exists( valid_agencies[ agency_id = ls_travel-AgencyID ] ).
        append value #(  %tky = ls_travel-%tky ) to failed-travel.

        append value #(  %tky               = ls_travel-%tky
                         %state_area        = 'VALIDATE_AGENCY'
                         %msg               = new /dmo/cm_flight_messages(
                                                                agency_id = ls_travel-agencyid
                                                                textid    = /dmo/cm_flight_messages=>agency_unkown
                                                                severity  = if_abap_behv_message=>severity-error )
                         %element-AgencyID  = if_abap_behv=>mk-on
                      ) to reported-travel.
      endif.

    endloop.

  endmethod.

  method validateCustomer.

    read entities of zr_travel_lgl in local mode
         entity Travel
         fields ( CustomerID )
         with corresponding #( keys )
         result data(lt_travels).

    data lt_customers type sorted table of /dmo/customer with unique key client customer_id.

    " Optimization of DB select: extract distinct non-initial customer IDs
    lt_customers = corresponding #( lt_travels discarding duplicates
                                               mapping customer_id = CustomerID except * ).
    delete lt_customers where customer_id is initial.

    if  lt_customers is not initial.

      " Check if customer ID exists
      select from @lt_customers as it_cust
             inner join /dmo/customer as db_cust
                   on it_cust~customer_id eq db_cust~customer_id
             fields it_cust~customer_id
             into table @data(lt_valid_customers).

    endif.

    " Raise message for non existing customer id
    loop at lt_travels into data(ls_travel).

      append value #(  %tky                 = ls_travel-%tky
                       %state_area          = 'VALIDATE_CUSTOMER'
                     ) to reported-travel.

      if ls_travel-CustomerID is  initial.
        append value #( %tky = ls_travel-%tky ) to failed-travel.

        append value #( %tky                = ls_travel-%tky
                        %state_area         = 'VALIDATE_CUSTOMER'
                        %msg                = new /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>enter_customer_id
                                                                severity = if_abap_behv_message=>severity-error )
                        %element-CustomerID = if_abap_behv=>mk-on
                      ) to reported-travel.

      elseif ls_travel-CustomerID is not initial and not line_exists( lt_valid_customers[ customer_id = ls_travel-CustomerID ] ).
        append value #(  %tky = ls_travel-%tky ) to failed-travel.

        append value #(  %tky                = ls_travel-%tky
                         %state_area         = 'VALIDATE_CUSTOMER'
                         %msg                = new /dmo/cm_flight_messages(
                                                                customer_id = ls_travel-customerid
                                                                textid      = /dmo/cm_flight_messages=>customer_unkown
                                                                severity    = if_abap_behv_message=>severity-error )
                         %element-CustomerID = if_abap_behv=>mk-on
                      ) to reported-travel.
      endif.

    endloop.
  endmethod.

  method validateDates.

    read entities of zr_travel_lgl in local mode
       entity Travel
         fields (  BeginDate EndDate TravelID )
         with corresponding #( keys )
       result data(lt_travels).

    loop at lt_travels into data(ls_travel).

      append value #(  %tky               = ls_travel-%tky
                       %state_area        = 'VALIDATE_DATES' ) to reported-travel.

      if ls_travel-BeginDate is initial.
        append value #( %tky = ls_travel-%tky ) to failed-travel.

        append value #( %tky               = ls_travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg              = new /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>enter_begin_date
                                                                severity = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on ) to reported-travel.
      endif.
      if ls_travel-EndDate is initial.
        append value #( %tky = ls_travel-%tky ) to failed-travel.

        append value #( %tky               = ls_travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg                = new /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>enter_end_date
                                                                severity = if_abap_behv_message=>severity-error )
                        %element-EndDate   = if_abap_behv=>mk-on ) to reported-travel.
      endif.
      if ls_travel-EndDate < ls_travel-BeginDate and ls_travel-BeginDate is not initial
                                                 and ls_travel-EndDate   is not initial.
        append value #( %tky = ls_travel-%tky ) to failed-travel.

        append value #( %tky               = ls_travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = new /dmo/cm_flight_messages(
                                                                textid     = /dmo/cm_flight_messages=>begin_date_bef_end_date
                                                                begin_date = ls_travel-BeginDate
                                                                end_date   = ls_travel-EndDate
                                                                severity   = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on
                        %element-EndDate   = if_abap_behv=>mk-on ) to reported-travel.
      endif.
      if ls_travel-BeginDate < cl_abap_context_info=>get_system_date( ) and ls_travel-BeginDate is not initial.
        append value #( %tky               = ls_travel-%tky ) to failed-travel.

        append value #( %tky               = ls_travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg              = new /dmo/cm_flight_messages(
                                                                begin_date = ls_travel-BeginDate
                                                                textid     = /dmo/cm_flight_messages=>begin_date_on_or_bef_sysdate
                                                                severity   = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on ) to reported-travel.
      endif.

    endloop.
  endmethod.

  method is_create_granted.

    "For validation
    if country_code is supplied.
      authority-check object '/DMO/TRVL'
        id '/DMO/CNTRY' field country_code
        id 'ACTVT'      field '01'.
      create_granted = cond #( when sy-subrc = 0 then abap_true else abap_false ).

      "For global auth
    else.
      authority-check object '/DMO/TRVL'
        id '/DMO/CNTRY' dummy
        id 'ACTVT'      field '01'.
      create_granted = cond #( when sy-subrc = 0 then abap_true else abap_false ).
    endif.

    "Simulation for full authorization
    "(not to be used in productive code)
    create_granted = abap_true.

  endmethod.

  method is_delete_granted.

    "For instance auth
    if country_code is supplied.
      authority-check object '/DMO/TRVL'
        id '/DMO/CNTRY' field country_code
        id 'ACTVT'      field '06'.

      delete_granted = cond #( when sy-subrc = 0 then abap_true else abap_false ).

*      " simulation of auth check for demo,
*      " auth granted for country_code US, else not
      case country_code.
        when 'US'.
          delete_granted = abap_true.
        when others.
          delete_granted = abap_false.
      endcase.

      "For global auth
    else.
      authority-check object '/DMO/TRVL'
        id '/DMO/CNTRY' dummy
        id 'ACTVT'      field '06'.
      delete_granted = cond #( when sy-subrc = 0 then abap_true else abap_false ).
    endif.

    "Simulation for full authorization
    "(not to be used in productive code)
    delete_granted = abap_true.

  endmethod.

  method is_update_granted.

    "For instance auth
    if country_code is supplied.
      authority-check object '/DMO/TRVL'
        id '/DMO/CNTRY' field country_code
        id 'ACTVT'      field '02'.
      update_granted = cond #( when sy-subrc = 0 then abap_true else abap_false ).

      "For global auth
    else.
      authority-check object '/DMO/TRVL'
        id '/DMO/CNTRY' dummy
        id 'ACTVT'      field '02'.
      update_granted = cond #( when sy-subrc = 0 then abap_true else abap_false ).
    endif.

    "Simulation for full authorization
    "(not to be used in productive code)
    update_granted = abap_true.

  endmethod.

  method precheck_auth.

    data:
      entities          type t_entities_update,
      operation         type if_abap_behv=>t_char01,
      agencies          type sorted table of /dmo/agency with unique key agency_id,
      is_modify_granted type abap_bool.

    " Either entities_create or entities_update is provided.  NOT both and at least one.
    assert not ( entities_create is initial equiv entities_update is initial ).

    if entities_create is not initial.
      entities = corresponding #( entities_create mapping %cid_ref = %cid ).
      operation = if_abap_behv=>op-m-create.
    else.
      entities = entities_update.
      operation = if_abap_behv=>op-m-update.
    endif.

    delete entities where %control-AgencyID = if_abap_behv=>mk-off.

    agencies = corresponding #( entities discarding duplicates mapping agency_id = AgencyID except * ).

    check agencies is not initial.

    select from /dmo/agency fields agency_id, country_code
                            for all entries in @agencies
                            where agency_id = @agencies-agency_id
      into table @data(agency_country_codes).

    loop at entities into data(entity).
      is_modify_granted = abap_false.

      read table agency_country_codes with key agency_id = entity-AgencyID
                   assigning field-symbol(<agency_country_code>).

      "If invalid or initial AgencyID -> validateAgency
      check sy-subrc = 0.
      case operation.
        when if_abap_behv=>op-m-create. is_modify_granted = is_create_granted( <agency_country_code>-country_code ).
        when if_abap_behv=>op-m-update. is_modify_granted = is_update_granted( <agency_country_code>-country_code ).
      endcase.

      if is_modify_granted = abap_false.
        append value #(
                         %cid      = cond #( when operation = if_abap_behv=>op-m-create then entity-%cid_ref )
                         %tky      = entity-%tky
                       ) to failed.

        append value #(
                         %cid      = cond #( when operation = if_abap_behv=>op-m-create then entity-%cid_ref )
                         %tky      = entity-%tky
                         %msg      = new /dmo/cm_flight_messages(
                                                 textid    = /dmo/cm_flight_messages=>not_authorized_for_agencyid
                                                 agency_id = entity-AgencyID
                                                 severity  = if_abap_behv_message=>severity-error )
                         %element-AgencyID   = if_abap_behv=>mk-on
                      ) to reported.
      endif.

    endloop.

  endmethod.

endclass.
