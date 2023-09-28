@EndUserText.label: 'Booking - Composition Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED

@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['BookingID']

define view entity zc_booking_lgl
  as projection on zr_booking_lgl
{
  key BookingUUID,

      TravelUUID,

      @Search.defaultSearchElement: true
      BookingID,
      BookingDate,

      @ObjectModel.text.element: ['CustomerName']
      @Search.defaultSearchElement: true
      CustomerID,
      _Customer.LastName        as CustomerName,

      @ObjectModel.text.element: ['CarrierName']

      AirlineID,
      _Carrier.Name             as CarrierName,

      ConnectionID,

      FlightDate,
      FlightPrice,
      CurrencyCode,

      @ObjectModel.text.element: ['BookingStatusText']
      BookingStatus,
      _BookingStatus._Text.Text as BookingStatusText : localized,

      LocalLastChangedAt,

      /* Associations */
      _Travel : redirected to parent zc_travel_lgl,
      _BookingStatus,
      _Carrier,
      _Connection,
      _Customer

}
