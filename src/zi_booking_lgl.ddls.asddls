@EndUserText.label: 'Booking Interface Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity zi_booking_lgl
  as projection on zr_booking_lgl
{
  key BookingUUID,
      TravelUUID,
      BookingID,
      BookingDate,
      CustomerID,
      AirlineID,
      ConnectionID,
      FlightDate,
      FlightPrice,
      CurrencyCode,
      BookingStatus,
      LocalLastChangedAt,
      /* Associations */
      _BookingStatus,
      _Carrier,
      _Connection,
      _Customer,
      _Travel : redirected to parent zi_travel_lgl
}
