//
//  FriendTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 29.09.13.
//  Copyright © 2013-2016 Christoph Krey. All rights reserved.
//

#import "OwnTracksAppDelegate.h"
#import "Settings.h"
#import "FriendsTVC.h"
#import "WaypointTVC.h"
#import "PersonTVC.h"
#import "Friend+Create.h"
#import "FriendTableViewCell.h"
#import "Waypoint+Create.h"
#import "CoreData.h"
#import "FriendAnnotationV.h"
#import "OwnTracking.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface FriendsTVC ()
@property (strong, nonatomic) UIAlertView *alertView;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@end

@implementation FriendsTVC
static const DDLogLevel ddLogLevel = DDLogLevelError;

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    [[OwnTracking sharedInstance] addObserver:self
                                   forKeyPath:@"inQueue"
                                      options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                      context:nil];
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    
    switch (status) {
        case kABAuthorizationStatusRestricted:
            DDLogVerbose(@"ABAddressBookGetAuthorizationStatus: kABAuthorizationStatusRestricted");
            self.alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Addressbook Access",
                                                                                  @"Headline in addressbook related error messages")
                                                        message:NSLocalizedString(@"has been restricted, possibly due to restrictions such as parental controls.",
                                                                                  @"kABAuthorizationStatusRestricted")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK",
                                                                                  @"OK button title")
                                              otherButtonTitles:nil];
            [self.alertView show];
            break;
            
        case kABAuthorizationStatusDenied:
            DDLogVerbose(@"ABAddressBookGetAuthorizationStatus: kABAuthorizationStatusDenied");
            self.alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Addressbook Access",
                                                                                  @"Headline in addressbook related error messages")
                                                        message:NSLocalizedString(@"has been denied by user. Go to Settings/Privacy/Contacts to change",
                                                                                  @"kABAuthorizationStatusDenied")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK",
                                                                                  @"OK button title")
                                              otherButtonTitles:nil];
            [self.alertView show];
            break;
            
        case kABAuthorizationStatusAuthorized:
            DDLogVerbose(@"ABAddressBookGetAuthorizationStatus: kABAuthorizationStatusAuthorized");
            break;
            
        case kABAuthorizationStatusNotDetermined:
        default:
            DDLogVerbose(@"ABAddressBookGetAuthorizationStatus: kABAuthorizationStatusNotDetermined");
            ABAddressBookRef ab = ABAddressBookCreateWithOptions(NULL, NULL);
            ABAddressBookRequestAccessWithCompletion(ab, ^(bool granted, CFErrorRef error) {
                if (granted) {
                    DDLogVerbose(@"ABAddressBookRequestAccessCompletionHandler granted");
                } else {
                    DDLogVerbose(@"ABAddressBookRequestAccessCompletionHandler denied");
                }
            });
            break;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    [self performSelectorOnMainThread:@selector(setBadge:)
                           withObject:[OwnTracking sharedInstance].inQueue
                        waitUntilDone:NO];
}

- (void)setBadge:(NSNumber *)number {
    unsigned long inQueue = [number unsignedLongValue];
    DDLogVerbose(@"inQueue %lu", inQueue);
    if (inQueue > 0) {
        [self.navigationController.tabBarItem setBadgeValue:[NSString stringWithFormat:@"%lu", inQueue]];
    } else {
        [self.navigationController.tabBarItem setBadgeValue:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath = nil;
    
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        indexPath = [self.tableView indexPathForCell:sender];
    }
    
    if (indexPath) {
        Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];

        if ([segue.identifier isEqualToString:@"showWaypointFromFriends"]) {
            if ([segue.destinationViewController respondsToSelector:@selector(setWaypoint:)]) {
                Waypoint *waypoint = [friend newestWaypoint];
                if (waypoint) {
                    [segue.destinationViewController performSelector:@selector(setWaypoint:) withObject:waypoint];
                }
            }
        }

    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    UITabBarController *tbc;
    UINavigationController *nc;

    if (self.splitViewController) {
        UISplitViewController *svc = self.splitViewController;
        nc = svc.viewControllers[1];
    } else {
        tbc = self.tabBarController;
        NSArray *vcs = tbc.viewControllers;
        nc = vcs[0];
    }
    
    UIViewController *vc = nc.topViewController;

    if ([vc respondsToSelector:@selector(setCenter:)]) {
        [vc performSelector:@selector(setCenter:) withObject:friend];
        if (tbc) {
            tbc.selectedIndex = 0;
        }
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"friend" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        OwnTracksAppDelegate *delegate = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
        Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [delegate sendEmpty:friend.topic];
        [context deleteObject:friend];
        
        NSError *error = nil;
        if (![context save:&error]) {
            DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        }
    }
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Friend"
                                              inManagedObjectContext:[CoreData theManagedObjectContext]];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:20];
    
    NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@"topic" ascending:YES];
    
    NSArray *sortDescriptors = @[sortDescriptor1];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc]
                                                             initWithFetchRequest:fetchRequest
                                                             managedObjectContext:[CoreData theManagedObjectContext]
                                                             sectionNameKeyPath:nil
                                                             cacheName:nil];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
    NSError *error = nil;
    if (![self.fetchedResultsController performFetch:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        default:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [tableView reloadRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            [tableView insertRowsAtIndexPaths:@[newIndexPath]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    FriendTableViewCell *friendTableViewCell = (FriendTableViewCell *)cell;
    
    Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];

    friendTableViewCell.name.text = friend.name ? friend.name : friend.tid;
    
    FriendAnnotationV *friendAnnotationView = [[FriendAnnotationV alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    friendAnnotationView.personImage = friend.image ? [UIImage imageWithData:friend.image] : nil;
    friendAnnotationView.me = [friend.topic isEqualToString:[Settings theGeneralTopic]];
    friendAnnotationView.tid = [friend getEffectiveTid];

    Waypoint *waypoint = [friend newestWaypoint];
    if (waypoint) {
        [friendTableViewCell deferredReverseGeoCode:waypoint];
        
        friendTableViewCell.address.text = waypoint.placemark ? waypoint.placemark : NSLocalizedString(@"resolving...",
                                                                                                      @"temporary display while resolving address");
        friendAnnotationView.speed = [waypoint.vel doubleValue];
        friendAnnotationView.course = [waypoint.cog doubleValue];
    } else {
        friendAnnotationView.speed = -1;
        friendAnnotationView.course = -1;
    }
    
    NSDateComponents *dateComponents = [[NSCalendar currentCalendar] components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
                                                                       fromDate:[NSDate date]];
    NSDate *thisMorning = [[NSCalendar currentCalendar] dateFromComponents:dateComponents];
    if ([waypoint.tst timeIntervalSinceDate:thisMorning] > 0) {
        friendTableViewCell.timestamp.text = [NSDateFormatter localizedStringFromDate:waypoint.tst
                                                                            dateStyle:NSDateFormatterNoStyle
                                                                            timeStyle:NSDateFormatterShortStyle];
    } else {
        friendTableViewCell.timestamp.text = [NSDateFormatter localizedStringFromDate:waypoint.tst
                                                                            dateStyle:NSDateFormatterShortStyle
                                                                            timeStyle:NSDateFormatterNoStyle];
    }

    friendTableViewCell.image.image = [friendAnnotationView getImage];
}

@end
