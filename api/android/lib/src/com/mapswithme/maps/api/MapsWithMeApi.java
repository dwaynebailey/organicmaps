
package com.mapswithme.maps.api;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.net.Uri;
import android.widget.Toast;

import java.util.Locale;

//TODO add javadoc for public interface
public final class MapsWithMeApi
{

  public static void showPointsOnMap(Activity caller, MWMPoint... points)
  {
    showPointsOnMap(caller, null, null, points);
  }

  public static void showPointOnMap(Activity caller, double lat, double lon, String name, String id)
  {
    showPointsOnMap(caller, (String)null, (PendingIntent)null, new MWMPoint(lat, lon, name));
  }

  public static void showPointsOnMap(Activity caller, String title, MWMPoint... points)
  {
    showPointsOnMap(caller, title, null, points);
  }

  public static void showPointsOnMap(Activity caller, String title, PendingIntent pendingIntent, MWMPoint... points)
  {
    final Intent mwmIntent = new Intent(Const.ACTION_MWM_REQUEST);
    
    mwmIntent.putExtra(Const.EXTRA_URL, createMwmUrl(caller, title, points).toString());
    mwmIntent.putExtra(Const.EXTRA_TITLE, title);
    
    final boolean hasIntent = pendingIntent != null;
    mwmIntent.putExtra(Const.EXTRA_HAS_PENDING_INTENT, hasIntent);
    if (hasIntent)
      mwmIntent.putExtra(Const.EXTRA_CALLER_PENDING_INTENT, pendingIntent);

    addCommonExtras(caller, mwmIntent);

    if (isMapsWithMeInstalled(caller))
    {
      // Match activity for intent
      // TODO specify DEFAULT for Pro version.
      final ActivityInfo aInfo = caller.getPackageManager().resolveActivity(mwmIntent, 0).activityInfo;
      mwmIntent.setClassName(aInfo.packageName, aInfo.name);
      caller.startActivity(mwmIntent);
    }
    //TODO this is temporally solution, add dialog
    else 
      Toast.makeText(caller, "MapsWithMe is not installed.", Toast.LENGTH_LONG).show();
  }

  public static boolean isMapsWithMeInstalled(Context context)
  {
    final Intent intent = new Intent(Const.ACTION_MWM_REQUEST);
    return context.getPackageManager().resolveActivity(intent, 0) != null;
  }
 
  
  static StringBuilder createMwmUrl(Context context, String title, MWMPoint ... points)
  {
    StringBuilder urlBuilder = new StringBuilder("mapswithme://map?");
    // version
    urlBuilder.append("v=")
              .append(Const.API_VERSION)
              .append("&");
    // back url, always not null
    urlBuilder.append("backurl=")
              .append(getCallbackAction(context))
              .append("&");
    // title
    appendIfNotNull(urlBuilder, "appname", title);

    // points
    for (MWMPoint point : points)
    {
      if (point != null)
      { 
        urlBuilder.append("ll=")
                  .append(String.format(Locale.US, "%f,%f&", point.getLat(), point.getLon()));
        
        appendIfNotNull(urlBuilder, "n", point.getName());
        appendIfNotNull(urlBuilder, "u", point.getId());
      }
    }
    
    return urlBuilder;
  }

  static String getCallbackAction(Context context)
  {
    return Const.CALLBACK_PREFIX + context.getPackageName();
  }

  private static Intent addCommonExtras(Context context, Intent intent)
  {
    intent.putExtra(Const.EXTRA_CALLER_APP_INFO, context.getApplicationInfo());
    intent.putExtra(Const.EXTRA_API_VERSION, Const.API_VERSION);

    return intent;
  }
  
  private static StringBuilder appendIfNotNull(StringBuilder builder, String key, String value)
  {
    if (value != null)
      builder.append(key)
             .append("=")
             .append(Uri.encode(value))
             .append("&");
    
    return builder;
  }
}
