import json
from typing import Dict, Any, List, Optional, Callable
import firebase_admin
from firebase_admin import db
import time


# Initialize Firebase Admin SDK
_firebase_app = None

def _get_firebase_app():
    """
    Get or initialize Firebase Admin SDK instance.
    Uses default credentials (from environment or gcloud).
    
    Returns:
        Firebase app instance
    """
    global _firebase_app
    
    if _firebase_app is None:
        try:
            _firebase_app = firebase_admin.initialize_app(options={
                'databaseURL': 'https://empathy-exchange-473417-default-rtdb.firebaseio.com'
            })
        except ValueError:
            # App already initialized
            _firebase_app = firebase_admin.get_app()
    
    return _firebase_app


def add_to_chats_v2(payload: Dict[str, Any], key: Optional[str] = None) -> str:
    """
    Add a JSON payload to the chats_v2 path in Firebase Realtime Database.
    
    Args:
        payload: Dictionary containing the JSON data to add
        key: Optional key/path. If None, Firebase will auto-generate one using push().
    
    Returns:
        The key/path of the created entry
    
    Example:
        >>> data = {"message": "Hello", "sender": "user123", "timestamp": "2024-01-01T00:00:00Z"}
        >>> entry_key = add_to_chats_v2(data)
        >>> print(f"Added entry with key: {entry_key}")
    """
    _get_firebase_app()
    ref = db.reference('chats_v2')
    
    if key:
        # Set at specific key
        ref.child(key).set(payload)
        return key
    else:
        # Auto-generate key using push()
        new_ref = ref.push(payload)
        return new_ref.key


def query_chat_v2(filters: Optional[List[tuple]] = None, 
                  order_by: Optional[str] = None,
                  limit: Optional[int] = None) -> List[Dict[str, Any]]:
    """
    Query entries from the chat_v2 path in Firebase Realtime Database.
    
    Args:
        filters: Optional list of filter tuples in format (field, operator, value).
                 Operators: '==', '!=', '<', '<=', '>', '>='
                 Note: Realtime Database has limited query capabilities compared to Firestore
        order_by: Optional field name to order results by
        limit: Optional maximum number of entries to return
    
    Returns:
        List of dictionaries, each containing entry data with an added 'key' field
    
    Example:
        >>> # Get all entries
        >>> results = query_chat_v2()
        
        >>> # Query with filters (client-side filtering after fetching)
        >>> results = query_chat_v2(filters=[('sender', '==', 'user123')])
        
        >>> # Query with ordering and limit
        >>> results = query_chat_v2(
        ...     order_by='timestamp',
        ...     limit=10
        ... )
    """
    _get_firebase_app()
    ref = db.reference('chat_v2')
    
    # Get all data
    snapshot = ref.get()
    
    if snapshot is None:
        return []
    
    results = []
    
    # Convert snapshot to list of dicts with keys
    if isinstance(snapshot, dict):
        for key, value in snapshot.items():
            if isinstance(value, dict):
                entry = value.copy()
                entry['key'] = key
                results.append(entry)
            else:
                # If value is not a dict, wrap it
                results.append({'key': key, 'value': value})
    elif isinstance(snapshot, list):
        for i, value in enumerate(snapshot):
            if isinstance(value, dict):
                entry = value.copy()
                entry['key'] = str(i)
                results.append(entry)
            else:
                results.append({'key': str(i), 'value': value})
    
    # Apply client-side filtering
    if filters:
        filtered_results = []
        for entry in results:
            match = True
            for field, operator, value in filters:
                entry_value = entry.get(field)
                if operator == '==' and entry_value != value:
                    match = False
                    break
                elif operator == '!=' and entry_value == value:
                    match = False
                    break
                elif operator == '<' and not (entry_value is not None and entry_value < value):
                    match = False
                    break
                elif operator == '<=' and not (entry_value is not None and entry_value <= value):
                    match = False
                    break
                elif operator == '>' and not (entry_value is not None and entry_value > value):
                    match = False
                    break
                elif operator == '>=' and not (entry_value is not None and entry_value >= value):
                    match = False
                    break
            if match:
                filtered_results.append(entry)
        results = filtered_results
    
    # Apply client-side ordering
    if order_by:
        results.sort(key=lambda x: x.get(order_by, ''), reverse=False)
    
    # Apply limit
    if limit:
        results = results[:limit]
    
    return results


def query_chats_v2(user_in: Optional[str] = None,
                   order_by: Optional[str] = None,
                   limit: Optional[int] = None) -> List[Dict[str, Any]]:
    """
    Query entries from the chats_v2 path in Firebase Realtime Database.
    Supports filtering by checking if a user is in the 'users' field.
    
    Args:
        user_in: Optional user ID to filter chats where this user is in the 'users' array.
                 Example: user_in="user123" will return all chats where "user123" is in users.
        order_by: Optional field name to order results by
        limit: Optional maximum number of entries to return
    
    Returns:
        List of dictionaries, each containing entry data with an added 'key' field
    
    Example:
        >>> # Get all chats
        >>> results = query_chats_v2()
        
        >>> # Get chats where user123 is a participant
        >>> results = query_chats_v2(user_in="user123")
        
        >>> # Get chats with ordering and limit
        >>> results = query_chats_v2(
        ...     user_in="user123",
        ...     order_by='timestamp',
        ...     limit=10
        ... )
    """
    _get_firebase_app()
    ref = db.reference('chats_v2')
    
    # Get all data
    snapshot = ref.get()
    
    if snapshot is None:
        return []
    
    results = []
    
    # Convert snapshot to list of dicts with keys
    if isinstance(snapshot, dict):
        for key, value in snapshot.items():
            if isinstance(value, dict):
                entry = value.copy()
                entry['key'] = key
                results.append(entry)
            else:
                # If value is not a dict, wrap it
                results.append({'key': key, 'value': value})
    elif isinstance(snapshot, list):
        for i, value in enumerate(snapshot):
            if isinstance(value, dict):
                entry = value.copy()
                entry['key'] = str(i)
                results.append(entry)
            else:
                results.append({'key': str(i), 'value': value})
    
    # Apply user filtering
    if user_in:
        filtered_results = []
        for entry in results:
            users = entry.get('users', [])
            # Handle both list and other iterable types
            if isinstance(users, (list, tuple)):
                if user_in in users:
                    filtered_results.append(entry)
            elif users is not None:
                # If users is not a list, try to convert or check equality
                if user_in == users:
                    filtered_results.append(entry)
        results = filtered_results
    
    # Apply client-side ordering
    if order_by:
        results.sort(key=lambda x: x.get(order_by, ''), reverse=False)
    
    # Apply limit
    if limit:
        results = results[:limit]
    
    return results


# Convenience function to list all entries in chats_v2 path
def list_chats_v2_entries(limit: Optional[int] = None) -> List[Dict[str, Any]]:
    """
    List all entries from chats_v2 path.
    
    Args:
        limit: Optional maximum number of entries to return
    
    Returns:
        List of dictionaries, each containing entry data with an added 'key' field
    """
    _get_firebase_app()
    ref = db.reference('chats_v2')
    
    snapshot = ref.get()
    
    if snapshot is None:
        return []
    
    results = []
    
    # Convert snapshot to list of dicts with keys
    if isinstance(snapshot, dict):
        for key, value in snapshot.items():
            if isinstance(value, dict):
                entry = value.copy()
                entry['key'] = key
                results.append(entry)
            else:
                results.append({'key': key, 'value': value})
    elif isinstance(snapshot, list):
        for i, value in enumerate(snapshot):
            if isinstance(value, dict):
                entry = value.copy()
                entry['key'] = str(i)
                results.append(entry)
            else:
                results.append({'key': str(i), 'value': value})
    
    if limit:
        results = results[:limit]
    
    return results


def watch_database(path: str = 'chats_v2', 
                   callback: Optional[Callable] = None,
                   print_updates: bool = True):
    """
    Watch a Firebase Realtime Database path for updates and print the updated payload.
    The listener runs in a background thread automatically.
    
    Args:
        path: Database path to watch (e.g., 'chats_v2', 'chat_v2', 'chats_v2/some_key')
        callback: Optional custom callback function that receives an Event object.
                  Event has: event_type ('put' or 'patch'), path, and data.
                  If None, uses default printing behavior.
        print_updates: If True, prints updates to console. If False, only calls callback.
    
    Returns:
        None (listener runs in background thread automatically)
    
    Example:
        >>> # Watch all changes to chats_v2
        >>> watch_database('chats_v2')
        >>> # Keep script running to receive updates
        >>> import time
        >>> time.sleep(60)  # Listen for 60 seconds
        
        >>> # Custom callback
        >>> def my_callback(event):
        ...     print(f"Custom: {event.event_type} at {event.path} - {event.data}")
        >>> watch_database('chats_v2', callback=my_callback)
    """
    _get_firebase_app()
    ref = db.reference(path)
    
    def default_callback(event):
        """Default callback that prints updates."""
        if print_updates:
            timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
            print(f"\n[{timestamp}] {event.event_type.upper()} event on '{path}{event.path}':")
            if event.data is not None:
                print(json.dumps(event.data, indent=2, default=str))
            else:
                print("  (null)")
            print("-" * 80)
    
    def listener(event):
        """Handler for database events."""
        if callback:
            callback(event)
        else:
            default_callback(event)
    
    # Start the listener (runs in background thread automatically)
    ref.listen(listener)
    print(f"👀 Watching '{path}' for updates...")
    print("Press Ctrl+C to stop")


def watch_chats_v2(callback: Optional[Callable] = None, print_updates: bool = True):
    """
    Convenience function to watch the chats_v2 path for updates.
    
    Args:
        callback: Optional custom callback function that receives an Event object
        print_updates: If True, prints updates to console
    
    Returns:
        None (listener runs in background thread automatically)
    
    Example:
        >>> watch_chats_v2()
        >>> # Keep script running to receive updates
        >>> import time
        >>> time.sleep(60)  # Listen for 60 seconds
    """
    watch_database('chats_v2', callback=callback, print_updates=print_updates)


# Convenience function to get a single entry by key
def get_chat_v2_entry(entry_key: str) -> Optional[Dict[str, Any]]:
    """
    Get a single entry from chat_v2 path by key.
    
    Args:
        entry_key: The entry key to retrieve
    
    Returns:
        Dictionary containing entry data with 'key' field, or None if not found
    """
    _get_firebase_app()
    ref = db.reference(f'chat_v2/{entry_key}')
    snapshot = ref.get()
    
    if snapshot is None:
        return None
    
    if isinstance(snapshot, dict):
        entry = snapshot.copy()
        entry['key'] = entry_key
        return entry
    else:
        return {'key': entry_key, 'value': snapshot}


def main():
    import sys
    
    try:
        # Test adding an entry
        print("Adding entry to chats_v2...")
        entry_key = add_to_chats_v2({
            "users": ["user123", "user456"],
            "messages": [{"text": "Hello", "sender": "user123", "timestamp": "2024-01-01T00:00:00Z"}]
        })
        print(f"✓ Entry key returned: {entry_key}")
        
        # Verify the entry was created by reading it back
        print(f"\nVerifying entry was created...")
        _get_firebase_app()
        ref = db.reference(f'chats_v2/{entry_key}')
        snapshot = ref.get()
        
        if snapshot:
            print(f"✓ Entry verified! Data: {snapshot}")
        else:
            print(f"✗ ERROR: Entry with key {entry_key} was not found in Realtime Database!")
            sys.exit(1)
        
        # List all entries in chats_v2 to verify
        print(f"\nListing all entries in chats_v2 path...")
        all_entries = list_chats_v2_entries(limit=10)
        print(f"✓ Found {len(all_entries)} entry/entries in chats_v2")
        for i, entry in enumerate(all_entries, 1):
            print(f"  {i}. Entry key: {entry.get('key', 'N/A')}")
            print(f"     Users: {entry.get('users', [])}")
            print(f"     Messages: {len(entry.get('messages', []))} message(s)")
        
        # Test querying chats_v2 by user
        print(f"\nQuerying chats_v2 for user 'user123'...")
        user_chats = query_chats_v2(user_in="user123")
        print(f"✓ Found {len(user_chats)} chat(s) for user123")
        if user_chats:
            print(f"  Sample: {user_chats[0]}")
        
        # Test querying chat_v2
        print(f"\nQuerying chat_v2 path...")
        results = query_chat_v2()
        print(f"✓ Found {len(results)} entries in chat_v2")
        if results:
            print(f"  Sample: {results[0]}")
        
        # Test getting a specific entry
        print(f"\nTesting get_chat_v2_entry...")
        result = get_chat_v2_entry("123")
        if result:
            print(f"✓ Found entry: {result}")
        else:
            print("  (Entry '123' not found - this is expected if it doesn't exist)")
        
        print("\n✓ All tests completed successfully!")
        print(f"\n💡 Tip: Check Firebase Console at:")
        print(f"   https://console.firebase.google.com/project/empathy-exchange-473417/database/empathy-exchange-473417-default-rtdb/data")
        
    except Exception as e:
        print(f"\n✗ ERROR: {type(e).__name__}: {str(e)}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    # user_chats = query_chats_v2(user_in="user123")
    # print(f"✓ Found {len(user_chats)} chat(s) for user123")
    # if user_chats:
    #     print(f"  Sample: {user_chats[0]}")
    
    watch_chats_v2()
    time.sleep(60)

    # main()