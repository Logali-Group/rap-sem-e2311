@EndUserText.label: 'Travel Interface Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity zi_travel_lgl
  provider contract transactional_interface
  as projection on zr_travel_lgl
{
  key TravelUUID,
      TravelID,
      AgencyID,
      CustomerID,
      BeginDate,
      EndDate,
      BookingFee,
      TotalPrice,
      CurrencyCode,
      Description,
      OverallStatus,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,
      /* Associations */
      _Agency,
      _Booking : redirected to composition child zi_booking_lgl,
      _Currency,
      _Customer,
      _OverallStatus
}
