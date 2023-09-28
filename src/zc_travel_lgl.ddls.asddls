@EndUserText.label: 'Travel - Root Projection Entity'
@AccessControl.authorizationCheck: #NOT_REQUIRED

@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['TravelID']

define root view entity zc_travel_lgl
  provider contract transactional_query
  as projection on zr_travel_lgl
{
  key TravelUUID,

      @Search.defaultSearchElement: true
      TravelID,

      @Search.defaultSearchElement: true
      @ObjectModel.text.element: ['AgencyName']

      AgencyID,
      _Agency.Name              as AgencyName,

      @Search.defaultSearchElement: true
      @ObjectModel.text.element: ['CustomerName']
      CustomerID,
      _Customer.LastName        as CustomerName,

      BeginDate,
      EndDate,

      BookingFee,
      TotalPrice,
      CurrencyCode,

      Description,

      @ObjectModel.text.element: ['OverallStatusText']
      OverallStatus,
      _OverallStatus._Text.Text as OverallStatusText : localized,

      LocalLastChangedAt,
      
      /* Associations */
      _Agency,
      _Booking : redirected to composition child zc_booking_lgl,
      _Currency,
      _Customer,
      _OverallStatus
}
