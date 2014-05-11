#import "PlacePageVC.h"
#import "SelectSetVC.h"
#import "Statistics.h"
#import "MapsAppDelegate.h"
#import "MapViewController.h"
#import "TwoButtonsView.h"
#import "ShareActionSheet.h"
#import "PlaceAndCompasView.h"
#import "CircleView.h"
#import "UIKitCategories.h"

#include "Framework.h"
#include "../../search/result.hpp"
#include "../../platform/settings.hpp"

#define TEXTFIELD_TAG 999
#define TEXTVIEW_TAG 666
#define COORDINATE_TAG 333
#define MARGIN 20
#define SMALLMARGIN 10
#define DESCRIPTIONHEIGHT 140
#define TWOBUTTONSHEIGHT 44
#define CELLHEIGHT  44
#define COORDINATECOLOR 51.0/255.0
#define BUTTONDIAMETER 18

@interface PlacePageVC() <UIWebViewDelegate>
{
  int m_selectedRow;
  size_t m_categoryIndex;

  //statistics purpose
  size_t m_categoryIndexStatistics;
  size_t m_numberOfCategories;
  UIWebView * webView;
}

@property(nonatomic, copy) NSString * pinTitle;
// Currently displays bookmark description (notes)
@property(nonatomic, copy) NSString * pinNotes;
// Stores displayed bookmark icon file name
@property(nonatomic) NSString * pinColor;
// If we clicked already existing bookmark, it will be here
@property(nonatomic) BookmarkAndCategory pinEditedBookmark;

@property(nonatomic) CGPoint pinGlobalPosition;

@property (nonatomic) PlaceAndCompasView * placeAndCompass;

@property (nonatomic) UIView * pickerView;
@property (nonatomic) ShareActionSheet * shareActionSheet;

@end

@implementation PlacePageVC

- (id)initWithInfo:(search::AddressInfo const &)info point:(CGPoint)point
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self)
  {
    char const * pinName = info.GetPinName().c_str();
    [self initializeProperties:[NSString stringWithUTF8String:pinName ? pinName : ""]
                         notes:@""
                         color:@""
                         category:MakeEmptyBookmarkAndCategory() point:point];
    self.mode = PlacePageVCModeEditing;
  }
  return self;
}

- (id)initWithApiPoint:(url_scheme::ApiPoint const &)apiPoint
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self)
  {
    self.mode = PlacePageVCModeEditing;
    [self initializeProperties:[NSString stringWithUTF8String:apiPoint.m_name.c_str()]
                         notes:@""
                         color:@""
                         category:MakeEmptyBookmarkAndCategory()
                         point:CGPointMake(MercatorBounds::LonToX(apiPoint.m_lon), MercatorBounds::LatToY(apiPoint.m_lat))];
  }
  return self;
}

- (id)initWithBookmark:(BookmarkAndCategory)bmAndCat
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self)
  {
    Framework const & f = GetFramework();

    BookmarkCategory const * cat = f.GetBmCategory(bmAndCat.first);
    Bookmark const * bm = cat->GetBookmark(bmAndCat.second);
    search::AddressInfo info;

    CGPoint const pt = CGPointMake(bm->GetOrg().x, bm->GetOrg().y);
    f.GetAddressInfoForGlobalPoint(bm->GetOrg(), info);


    [self initializeProperties:[NSString stringWithUTF8String:bm->GetName().c_str()]
                         notes:[NSString stringWithUTF8String:bm->GetDescription().c_str()]
                         color:[NSString stringWithUTF8String:bm->GetType().c_str()]
                         category:bmAndCat
                         point:CGPointMake(pt.x, pt.y)];

    self.mode = PlacePageVCModeSaved;
  }
  return self;
}

- (id)initWithName:(NSString *)name andGlobalPoint:(CGPoint)point
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self)
  {
    self.mode = PlacePageVCModeEditing;
    [self initializeProperties:name
                         notes:@""
                         color:@""
                         category:MakeEmptyBookmarkAndCategory()
                         point:point];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged) name:UIDeviceOrientationDidChangeNotification object:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
  // Update the table - we can display it after changing set or color
  [self.tableView reloadData];

  // Automatically show keyboard if bookmark has default name
  if ([_pinTitle isEqualToString:NSLocalizedString(@"dropped_pin", nil)])
    [[[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].contentView viewWithTag:TEXTFIELD_TAG] becomeFirstResponder];

  if (IPAD)
  {
    CGSize size = CGSizeMake(320, 480);
    self.contentSizeForViewInPopover = size;
  }
  [super viewWillAppear:animated];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.title = NSLocalizedString(@"info", nil);
  if (self.mode == PlacePageVCModeEditing)
    [self addRightNavigationItemWithAction:@selector(save)];
  else
    [self addRightNavigationItemWithAction:@selector(edit)];

  self.tableView.backgroundView = nil;
  self.tableView.backgroundColor = [UIColor applicationBackgroundColor];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  if (self.mode == PlacePageVCModeEditing)
    return 4;
  else
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (self.mode == PlacePageVCModeEditing)
    switch (section)
    {
      //name
      case 0: return 1;
      //set
      case 1: return 1;
      //color picker
      case 2: return 1;
      //description
      case 3: return 1;
    }
  else
    switch (section)
    {
      //return zero, because want to use headers and footers
      //coordinates cell
      case 0: return 0;
      case 1: return 0;
    }
  return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == 3 && self.mode == PlacePageVCModeEditing)
    return DESCRIPTIONHEIGHT;
  return CELLHEIGHT;
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView
{
  [webView sizeToFit];
  [self.tableView reloadData];
  [UIView animateWithDuration:0.3 animations:^{
    webView.alpha = 1;
  }];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
  if (navigationType == UIWebViewNavigationTypeLinkClicked)
  {
    [[UIApplication sharedApplication] openURL:request.URL];
    return NO;
  }
  return YES;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  if (section == 0 && self.mode == PlacePageVCModeSaved)
    return TWOBUTTONSHEIGHT;
  return [self.tableView sectionHeaderHeight];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
  if (section == 0 && [self.pinNotes length] && self.mode == PlacePageVCModeSaved)
    return webView.scrollView.contentSize.height + 10;
  return [self.tableView sectionFooterHeight];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  if (section == 0 && self.mode == PlacePageVCModeSaved)
    return [[TwoButtonsView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, TWOBUTTONSHEIGHT)
                              leftButtonSelector:@selector(share)
                             rightButtonSelector:@selector(remove)
                                 leftButtonTitle:NSLocalizedString(@"share", nil)
                                rightButtontitle:NSLocalizedString(@"remove_pin", nil)
                                          target:self];
  return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
  if (self.mode == PlacePageVCModeSaved && section == 0 && [self.pinNotes length])
  {
    UIView * contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.width, 20)];
    if (!webView)
    {
      CGFloat xOffset = 7;
      CGFloat yOffset = 7;
      webView = [[UIWebView alloc] initWithFrame:CGRectMake(xOffset, yOffset, contentView.width - 2 * xOffset, contentView.height - yOffset)];
      webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
      webView.alpha = 0;
      webView.opaque = NO;
      webView.backgroundColor = [UIColor clearColor];
      webView.delegate = self;
      NSString * text = [NSString stringWithFormat:@"<font face=\"helvetica\">%@</font>", self.pinNotes];
      [webView loadHTMLString:text baseURL:nil];
    }
    [contentView addSubview:webView];
    return contentView;
  }
  return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell * cell = nil;
  if (self.mode == PlacePageVCModeEditing)
    cell = [self cellForEditingModeWithTable:tableView cellForRowAtIndexPath:indexPath];
  else
    cell = [self cellForSaveModeWithTable:tableView cellForRowAtIndexPath:indexPath];
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
  if (self.mode == PlacePageVCModeEditing)
  {
    if (indexPath.section == 1)
    {
//      SelectSetVC * vc = [[SelectSetVC alloc] initWithIndex:&m_categoryIndex];
//      [self pushToNavigationControllerAndSetControllerToPopoverSize:vc];
    }
    else if (indexPath.section == 2)
      [self showPicker];

    return;
  }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
  if ([textField.text length] == 0)
    return YES;
  // Hide keyboard
  [textField resignFirstResponder];

  if (![textField.text isEqualToString:_pinTitle])
  {
    self.pinTitle = textField.text;
    self.navigationController.title = textField.text;
  }
  return NO;
}

- (void)pushToNavigationControllerAndSetControllerToPopoverSize:(UIViewController *)vc
{
  if (IPAD)
    [vc setContentSizeForViewInPopover:[self contentSizeForViewInPopover]];
  [self.navigationController pushViewController:vc animated:YES];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
	return 1;
}

- (void)getSuperView:(double &)height width:(double &)width rect:(CGRect &)rect
{
  if (!IPAD)
  {
    rect = [UIScreen mainScreen].bounds;
    height = self.view.window.frame.size.height;
    width  = self.view.window.frame.size.width;
    if(!UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
      std::swap(height, width);
  }
  else
  {
    height = self.view.superview.frame.size.height;
    width = self.view.superview.frame.size.width;
    rect = self.view.superview.frame;
  }
}

- (void)addRightNavigationItemWithAction:(SEL)selector
{
  UIBarButtonItem * but;
  if (self.mode == PlacePageVCModeSaved)
    but = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:selector];
  else
    but = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:selector];
  self.navigationItem.rightBarButtonItem = but;
}

- (void)save
{
  [self.view endEditing:YES];
  [self savePin];
  [self goToTheMap];
  GetFramework().GetBalloonManager().Hide();
}

- (void)edit
{
  self.mode = PlacePageVCModeEditing;
  [self.tableView reloadData];
  [self addRightNavigationItemWithAction:@selector(save)];
}

- (void)remove
{
  if (IsValid(_pinEditedBookmark))
  {
    BookmarkCategory * cat = GetFramework().GetBmCategory(_pinEditedBookmark.first);
    if (cat->GetBookmarksCount() > _pinEditedBookmark.second)
      [self deleteBookmarkInCategory:cat];
  }
  [self goToTheMap];
}

- (void)deleteBookmarkInCategory:(BookmarkCategory *)category
{
  category->DeleteBookmark(_pinEditedBookmark.second);
  category->SaveToKMLFile();
  NSValue * value = [NSValue valueWithBytes:&_pinEditedBookmark objCType:@encode(BookmarkAndCategory)];
  [[NSNotificationCenter defaultCenter] postNotificationName:BOOKMARK_DELETED_NOTIFICATION object:value];
}

- (void)share
{
  ShareInfo * info = [[ShareInfo alloc] initWithText:self.pinTitle gX:_pinGlobalPosition.x gY:_pinGlobalPosition.y myPosition:NO];
  self.shareActionSheet = [[ShareActionSheet alloc] initWithInfo:info viewController:self];
  [self.shareActionSheet show];
}

- (void)savePin
{
  Framework & f = GetFramework();
  if (_pinEditedBookmark == MakeEmptyBookmarkAndCategory())
  {
    if ([self.pinNotes length] != 0)
      [[Statistics instance] logEvent:@"New Bookmark Description Field Occupancy" withParameters:@{@"Occupancy" : @"Filled"}];
    else
      [[Statistics instance] logEvent:@"New Bookmark Description Field Occupancy" withParameters:@{@"Occupancy" : @"Empty"}];

    if (m_categoryIndexStatistics != m_categoryIndex)
      [[Statistics instance] logEvent:@"New Bookmark Category" withParameters:@{@"Changed" : @"YES"}];
    else
      [[Statistics instance] logEvent:@"New Bookmark Category" withParameters:@{@"Changed" : @"NO"}];

    if (m_numberOfCategories != GetFramework().GetBmCategoriesCount())
      [[Statistics instance] logEvent:@"New Bookmark Category Set Was Created" withParameters:@{@"Created" : @"YES"}];
    else
      [[Statistics instance] logEvent:@"New Bookmark Category Set Was Created" withParameters:@{@"Created" : @"NO"}];

    int value = 0;
    if (Settings::Get("NumberOfBookmarksPerSession", value))
      Settings::Set("NumberOfBookmarksPerSession", ++value);
    [self addBookmarkToCategory:m_categoryIndex];
  }
  else
  {
    BookmarkCategory * cat = f.GetBmCategory(_pinEditedBookmark.first);
    Bookmark * bm = cat->GetBookmark(_pinEditedBookmark.second);

    if ([self.pinColor isEqualToString:[NSString stringWithUTF8String:bm->GetType().c_str()]])
      [[Statistics instance] logEvent:@"Bookmark Color" withParameters:@{@"Changed" : @"NO"}];
    else
      [[Statistics instance] logEvent:@"Bookmark Color" withParameters:@{@"Changed" : @"YES"}];

    if ([self.pinNotes isEqualToString:[NSString stringWithUTF8String:bm->GetDescription().c_str()]])
      [[Statistics instance] logEvent:@"Bookmark Description Field" withParameters:@{@"Changed" : @"NO"}];
    else
      [[Statistics instance] logEvent:@"Bookmark Description Field" withParameters:@{@"Changed" : @"YES"}];

    if (_pinEditedBookmark.first != m_categoryIndex)
    {
      [[Statistics instance] logEvent:@"Bookmark Category" withParameters:@{@"Changed" : @"YES"}];
      [self deleteBookmarkInCategory:cat];
      [self addBookmarkToCategory:m_categoryIndex];
    }
    else
    {
      [[Statistics instance] logEvent:@"Bookmark Category" withParameters:@{@"Changed" : @"NO"}];

      BookmarkData newBm([self.pinTitle UTF8String], [self.pinColor UTF8String]);
      newBm.SetDescription([self.pinNotes UTF8String]);
      f.ReplaceBookmark(_pinEditedBookmark.first, _pinEditedBookmark.second, newBm);
    }
    [self.delegate placePageVC:self didUpdateBookmarkAndCategory:_pinEditedBookmark];
  }
}

- (void)addBookmarkToCategory:(size_t)index
{
  BookmarkData bm([self.pinTitle UTF8String], [self.pinColor UTF8String]);
  bm.SetDescription([self.pinNotes UTF8String]);

  _pinEditedBookmark = pair<int, int>(index, GetFramework().AddBookmark(index, m2::PointD(_pinGlobalPosition.x, _pinGlobalPosition.y), bm));
  [self.delegate placePageVC:self didUpdateBookmarkAndCategory:_pinEditedBookmark];
}

- (void)initializeProperties:(NSString *)name notes:(NSString *)notes color:(NSString *)color category:(BookmarkAndCategory) bmAndCat point:(CGPoint)point
{
  Framework & f = GetFramework();

  self.pinTitle = name;
  self.pinNotes = notes;
  self.pinColor = (color.length == 0 ? [NSString stringWithUTF8String:f.LastEditedBMType().c_str()] : color);
  self.pinEditedBookmark = bmAndCat;
  m_categoryIndex = (bmAndCat.first == - 1 ? f.LastEditedBMCategory() : bmAndCat.first);
  self.pinGlobalPosition = point;

  m_categoryIndexStatistics = m_categoryIndex;
  m_numberOfCategories = f.GetBmCategoriesCount();
  m_selectedRow = [ColorPickerView getColorIndex:self.pinColor];
}

- (UITableViewCell *)cellForEditingModeWithTable:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSString * cellId;
  switch (indexPath.section)
  {
    case 0: cellId = @"EditingNameCellId"; break;
    case 1: cellId = @"EditingSetCellId"; break;
    case 2: cellId = @"EditingColorCellId"; break;
    default: cellId = @"EditingDF"; break;
  }
  UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:cellId];
  if (!cell)
  {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
    if (indexPath.section == 0)
    {
      cell.textLabel.text = NSLocalizedString(@"name", @"Add bookmark dialog - bookmark name");
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      // Temporary, to init font and color
      cell.detailTextLabel.text = @"temp string";
      // Called to initialize frames and fonts
      [cell layoutSubviews];
      CGRect const leftR = cell.textLabel.frame;
      CGFloat const padding = leftR.origin.x;
      CGRect r = CGRectMake(padding + leftR.size.width + padding, leftR.origin.y,
                            cell.contentView.frame.size.width - 3 * padding - leftR.size.width, leftR.size.height);
      UITextField * f = [[UITextField alloc] initWithFrame:r];
      f.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
      f.enablesReturnKeyAutomatically = YES;
      f.returnKeyType = UIReturnKeyDone;
      f.clearButtonMode = UITextFieldViewModeWhileEditing;
      f.autocorrectionType = UITextAutocorrectionTypeNo;
      f.textAlignment = UITextAlignmentRight;
      f.textColor = cell.detailTextLabel.textColor;
      f.font = [cell.detailTextLabel.font fontWithSize:[cell.detailTextLabel.font pointSize]];
      f.tag = TEXTFIELD_TAG;
      f.delegate = self;
      f.autocapitalizationType = UITextAutocapitalizationTypeWords;
      [f addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
      // Reset temporary font
      cell.detailTextLabel.text = nil;
      [cell.contentView addSubview:f];
    }
    else if (indexPath.section == 1)
    {
      cell.textLabel.text = NSLocalizedString(@"set", @"Add bookmark dialog - bookmark set");
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    else if (indexPath.section == 2)
    {
      cell.textLabel.text = NSLocalizedString(@"color", @"Add bookmark dialog - bookmark color");
    }
    else if (indexPath.section == 3)
    {
      cell.selectionStyle = UITableViewCellSelectionStyleNone;
      // Temporary, to init font and color
      cell.detailTextLabel.text = @"temp string";
      // Called to initialize frames and fonts
      [cell layoutSubviews];
      UITextView * txtView = [[UITextView alloc] initWithFrame:CGRectMake(10.0, 0.0, 300.0, 142.0)];
      txtView.delegate = self;
      txtView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      txtView.textColor = cell.detailTextLabel.textColor;
      txtView.font = [cell.detailTextLabel.font fontWithSize:[cell.detailTextLabel.font pointSize]];
      txtView.backgroundColor = [UIColor clearColor];
      txtView.tag = TEXTVIEW_TAG;
      cell.detailTextLabel.text = @"";
      [cell.contentView addSubview:txtView];
      txtView.delegate = self;
    }
  }
  switch (indexPath.section)
  {
    case 0:
      ((UITextField *)[cell.contentView viewWithTag:TEXTFIELD_TAG]).text = self.pinTitle;
      break;

    case 1:
      cell.detailTextLabel.text = [NSString stringWithUTF8String:GetFramework().GetBmCategory(m_categoryIndex)->GetName().c_str()];
      break;

    case 2:
      cell.accessoryView = [[UIImageView alloc] initWithImage:[CircleView createCircleImageWith:BUTTONDIAMETER andColor:[ColorPickerView buttonColor:m_selectedRow]]];
      break;
    case 3:
      UITextView * textView = (UITextView *)[cell viewWithTag:TEXTVIEW_TAG];
      textView.text = [self.pinNotes length] ? self.pinNotes : [self descriptionPlaceholderText];
      break;
  }
  return cell;
}

- (UITableViewCell *)cellForSaveModeWithTable:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell * cell = nil;
  if (indexPath.section == 0)
  {
    cell = [tableView dequeueReusableCellWithIdentifier:@"CoordinatesCELL"];
    if (!cell)
    {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CoordinatesCELL"];
      cell.textLabel.textAlignment = UITextAlignmentCenter;
      cell.textLabel.font = [UIFont fontWithName:@"Helvetica" size:26];
      cell.textLabel.textColor = [UIColor colorWithRed:COORDINATECOLOR green:COORDINATECOLOR blue:COORDINATECOLOR alpha:1.0];
      UILongPressGestureRecognizer * longTouch = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
      longTouch.minimumPressDuration = 0.5;
      longTouch.delegate = self;
      [cell addGestureRecognizer:longTouch];
    }
    cell.textLabel.text = [self coordinatesToString];
  }
  return cell;
}

- (void)orientationChanged
{
  if (self.mode == PlacePageVCModeSaved)
  {
    [self.placeAndCompass drawView];
    [self.tableView reloadData];
  }
}

- (void)goToTheMap
{
  GetFramework().GetBalloonManager().Hide();
  if (IPAD)
    [[MapsAppDelegate theApp].m_mapViewController dismissPopover];
  else
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (CGFloat)getDescriptionHeight
{
  return [self.pinNotes sizeWithFont:[UIFont fontWithName:@"Helvetica" size:18] constrainedToSize:CGSizeMake(self.tableView.frame.size.width - 3 * SMALLMARGIN, CGFLOAT_MAX) lineBreakMode:NSLineBreakByCharWrapping].height;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
  {
    CGPoint p = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint:p];
    if (indexPath != nil)
    {
      [self becomeFirstResponder];
      UIMenuController * menu = [UIMenuController sharedMenuController];
      [menu setTargetRect:[self.tableView rectForRowAtIndexPath:indexPath] inView:self.tableView];
      [menu setMenuVisible:YES animated:YES];
    }
  }
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  if (action == @selector(copy:))
    return YES;
  return NO;
}

- (BOOL)canBecomeFirstResponder
{
  return YES;
}

- (void)copy:(id)sender
{
  [UIPasteboard generalPasteboard].string = [self coordinatesToString];
}

- (NSString *)coordinatesToString
{
  NSLocale * decimalPointLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
  return [[NSString alloc] initWithFormat:@"%@" locale:decimalPointLocale, [NSString stringWithFormat:@"%.05f %.05f", MercatorBounds::YToLat(self.pinGlobalPosition.y), MercatorBounds::XToLon(self.pinGlobalPosition.x)]];
}

-(void)textFieldDidChange:(UITextField *)textField
{
  if (textField.tag == TEXTFIELD_TAG)
    self.pinTitle = textField.text;
}

- (void)textViewDidChange:(UITextView *)textView
{
  if (textView.tag == TEXTVIEW_TAG)
    self.pinNotes = textView.text;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
  if (![self.pinNotes length])
    textView.text = @"";
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
  if (![self.pinNotes length])
    textView.text = [self descriptionPlaceholderText];
}

- (NSString *)descriptionPlaceholderText
{
  return NSLocalizedString(@"description", nil);
}

- (void)showPicker
{
  double height, width;
  CGRect rect;
  [self getSuperView:height width:width rect:rect];
  self.pickerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
  ColorPickerView * colorPicker = [[ColorPickerView alloc] initWithWidth:min(height, width) andSelectButton:m_selectedRow];
  colorPicker.delegate = self;
  CGRect r = colorPicker.frame;
  r.origin.x = (self.pickerView.frame.size.width - colorPicker.frame.size.width) / 2;
  r.origin.y = (self.pickerView.frame.size.height - colorPicker.frame.size.height) / 2;
  colorPicker.frame = r;
  [self.pickerView addSubview:colorPicker];
  self.pickerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.pickerView setBackgroundColor:[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5]];
  UITapGestureRecognizer * tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissPicker)];
  [self.pickerView addGestureRecognizer:tap];
  if (!IPAD)
  {
    [self.view endEditing:YES];
    UIWindow * window = [UIApplication sharedApplication].keyWindow;
    if (!window)
      window = [[UIApplication sharedApplication].windows objectAtIndex:0];
    [[[window subviews] objectAtIndex:0] addSubview:self.pickerView];
  }
  else
    [self.view.superview addSubview:self.pickerView];
}

- (void)dismissPicker
{
  [self.pickerView removeFromSuperview];
}

- (void)colorPicked:(size_t)colorIndex
{
  if (colorIndex != m_selectedRow)
  {
    [[Statistics instance] logEvent:@"Select Bookmark color"];
    self.pinColor = [ColorPickerView colorName:colorIndex];
    if (!IsValid(self.pinEditedBookmark))
      [[Statistics instance] logEvent:@"New Bookmark Color Changed"];
    [self.tableView reloadData];
    m_selectedRow = colorIndex;
  }
  [self dismissPicker];
}

@end
