class zcl_data_generator_lgl definition
  public
  final
  create public .

  public section.
    interfaces if_oo_adt_classrun.

  protected section.
  private section.
endclass.



class zcl_data_generator_lgl implementation.

  method if_oo_adt_classrun~main.

    out->write( |----> Travel| ).

    delete from ztravel_lgl_a.                          "#EC CI_NOWHERE
    delete from ztravel_lgl_d.                          "#EC CI_NOWHERE

    insert ztravel_lgl_a from (
      select from /dmo/travel fields
        " client
        uuid( ) as travel_uuid,
        travel_id,
        agency_id,
        customer_id,
        begin_date,
        end_date,
        booking_fee,
        total_price,
        currency_code,
        description,
        case status when 'B' then 'A'
                    when 'P' then 'O'
                    when 'N' then 'O'
                    else 'X' end as overall_status,
        createdby as local_created_by,
        createdat as local_created_at,
        lastchangedby as local_last_changed_by,
        lastchangedat as local_last_changed_at,
        lastchangedat as last_changed_at
       where travel_id between '00000001' and '00000025'
    ).

    if sy-subrc eq 0.
      out->write( |Travel entries inserted:  { sy-dbcnt }| ).
    endif.

    " bookings
    out->write( |----> Bookings| ).

    delete from zbooking_lgl_a.                         "#EC CI_NOWHERE
    delete from zbooking_lgl_d.                         "#EC CI_NOWHERE

    insert zbooking_lgl_a from (
        select
          from /dmo/booking
            join ztravel_lgl_a on /dmo/booking~travel_id = ztravel_lgl_a~travel_id
            join /dmo/travel on /dmo/travel~travel_id = /dmo/booking~travel_id
          fields  "client,
                  uuid( ) as booking_uuid,
                  ztravel_lgl_a~travel_uuid as parent_uuid,
                  /dmo/booking~booking_id,
                  /dmo/booking~booking_date,
                  /dmo/booking~customer_id,
                  /dmo/booking~carrier_id,
                  /dmo/booking~connection_id,
                  /dmo/booking~flight_date,
                  /dmo/booking~flight_price,
                  /dmo/booking~currency_code,
                  case /dmo/travel~status when 'P' then 'N'
                                                   else /dmo/travel~status end as booking_status,
                  ztravel_lgl_a~last_changed_at as local_last_changed_at
    ).

    if sy-subrc eq 0.
      out->write( |Booking entries inserted:  { sy-dbcnt }| ).
    endif.

  endmethod.

endclass.
